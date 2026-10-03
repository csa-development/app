import mimetypes
import os
import re

from django.conf import settings
from django.core import signing
from django.http import Http404, HttpResponse, StreamingHttpResponse
from django.utils._os import safe_join
from django.views.static import serve as plain_serve

_RANGE_RE = re.compile(r'^bytes=(\d*)-(\d*)$')
_CHUNK = 64 * 1024

# Reporter-submitted evidence lives under this folder of MEDIA_ROOT. It is
# sensitive (victim photos/videos), so it is never served by the public
# /media/ route — only through serve_evidence() below.
EVIDENCE_PREFIX = 'incident_evidence/'
EVIDENCE_LINK_SALT = 'csa.incident-evidence'
EVIDENCE_LINK_MAX_AGE = 30 * 60  # seconds a signed link keeps working

# The only types ever served as evidence, and the Content-Type each gets.
# Chosen by extension from this fixed table — never guessed from content —
# so an HTML/SVG/script file can't be handed to a browser as a web page.
EVIDENCE_CONTENT_TYPES = {
    'jpg': 'image/jpeg',
    'png': 'image/png',
    'gif': 'image/gif',
    'webp': 'image/webp',
    'heic': 'image/heic',
    'mp4': 'video/mp4',
    'mov': 'video/quicktime',
    '3gp': 'video/3gpp',
    'webm': 'video/webm',
    'avi': 'video/x-msvideo',
}


def _iter_range(file_obj, length):
    try:
        remaining = length
        while remaining > 0:
            chunk = file_obj.read(min(_CHUNK, remaining))
            if not chunk:
                break
            remaining -= len(chunk)
            yield chunk
    finally:
        file_obj.close()


def _iter_whole(file_obj):
    try:
        while True:
            chunk = file_obj.read(_CHUNK)
            if not chunk:
                break
            yield chunk
    finally:
        file_obj.close()


def _file_response(request, full_path, content_type):
    """Serves one file with byte-range support (browsers need it to play
    and seek videos; Safari won't play a video without it)."""
    size = os.path.getsize(full_path)
    match = _RANGE_RE.match(request.headers.get('Range', '').strip())

    if not match or match.group(1) == match.group(2) == '':
        response = StreamingHttpResponse(
            _iter_whole(open(full_path, 'rb')), content_type=content_type)
        response['Content-Length'] = str(size)
        response['Accept-Ranges'] = 'bytes'
        return response

    start_text, end_text = match.groups()
    if start_text == '':
        start = max(size - int(end_text), 0)  # "last N bytes"
        end = size - 1
    else:
        start = int(start_text)
        end = min(int(end_text), size - 1) if end_text else size - 1

    if start >= size or start > end:
        response = HttpResponse(status=416)
        response['Content-Range'] = f'bytes */{size}'
        return response

    length = end - start + 1
    file_obj = open(full_path, 'rb')
    file_obj.seek(start)
    response = StreamingHttpResponse(
        _iter_range(file_obj, length), status=206, content_type=content_type)
    response['Content-Length'] = str(length)
    response['Content-Range'] = f'bytes {start}-{end}/{size}'
    response['Accept-Ranges'] = 'bytes'
    return response


def serve_media(request, path, document_root):
    """Public media (news/event/campaign images etc.) with byte-range
    support. Evidence is refused here outright."""
    if path.replace('\\', '/').lstrip('/').startswith(EVIDENCE_PREFIX):
        raise Http404

    match = _RANGE_RE.match(request.headers.get('Range', '').strip())
    if not match or match.group(1) == match.group(2) == '':
        response = plain_serve(request, path, document_root=document_root)
        response['Accept-Ranges'] = 'bytes'
        return response

    try:
        full_path = safe_join(document_root, path)
    except ValueError:
        raise Http404
    if not os.path.isfile(full_path):
        raise Http404
    content_type, _ = mimetypes.guess_type(full_path)
    return _file_response(
        request, full_path, content_type or 'application/octet-stream')


def evidence_link(stored_name):
    """A short-lived signed URL for one evidence file. Only handed out to
    staff who passed the permission check on the incident API."""
    token = signing.dumps({'f': stored_name}, salt=EVIDENCE_LINK_SALT)
    return f'/api/evidence/{token}/'


def serve_evidence(request, token):
    try:
        data = signing.loads(
            token, salt=EVIDENCE_LINK_SALT, max_age=EVIDENCE_LINK_MAX_AGE)
        stored_name = data['f']
    except (signing.BadSignature, KeyError, TypeError):
        raise Http404

    if not stored_name.startswith(EVIDENCE_PREFIX):
        raise Http404
    extension = stored_name.rsplit('.', 1)[-1].lower()
    content_type = EVIDENCE_CONTENT_TYPES.get(extension)
    if content_type is None:
        raise Http404

    try:
        full_path = safe_join(settings.MEDIA_ROOT, stored_name)
    except ValueError:
        raise Http404
    if not os.path.isfile(full_path):
        raise Http404

    response = _file_response(request, full_path, content_type)
    response['Content-Disposition'] = f'inline; filename="evidence.{extension}"'
    response['X-Content-Type-Options'] = 'nosniff'
    response['Content-Security-Policy'] = "default-src 'none'; sandbox"
    response['Cross-Origin-Resource-Policy'] = 'same-origin'
    response['Cache-Control'] = 'private, no-store'
    return response
