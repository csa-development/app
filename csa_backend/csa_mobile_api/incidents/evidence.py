import uuid

# What a reporter may attach as evidence. Decided from the file's actual
# first bytes, never from the filename or Content-Type the client sends —
# both are trivially faked, which is how a script disguised as "photo.jpg"
# would otherwise get stored and later opened by CERT staff.
IMAGE_EXTENSIONS = {'jpg', 'png', 'gif', 'webp', 'heic'}
VIDEO_EXTENSIONS = {'mp4', 'mov', '3gp', 'webm', 'avi'}

_HEIC_BRANDS = {b'heic', b'heix', b'hevc', b'hevx', b'heim', b'heis', b'mif1', b'msf1'}
_QUICKTIME_BRANDS = {b'qt  '}
_3GP_BRANDS = {b'3gp4', b'3gp5', b'3gp6', b'3g2a', b'3ge6', b'3gg6'}


def sniff_extension(header):
    """Returns the canonical extension for a recognised photo/video, or
    None. `header` is the first ~16 bytes of the file."""
    if header[:3] == b'\xff\xd8\xff':
        return 'jpg'
    if header[:8] == b'\x89PNG\r\n\x1a\n':
        return 'png'
    if header[:6] in (b'GIF87a', b'GIF89a'):
        return 'gif'
    if header[:4] == b'RIFF' and header[8:12] == b'WEBP':
        return 'webp'
    if header[:4] == b'RIFF' and header[8:12] == b'AVI ':
        return 'avi'
    if header[:4] == b'\x1a\x45\xdf\xa3':
        return 'webm'  # Matroska/WebM
    if header[4:8] == b'ftyp':
        brand = header[8:12]
        if brand in _HEIC_BRANDS:
            return 'heic'
        if brand in _QUICKTIME_BRANDS:
            return 'mov'
        if brand in _3GP_BRANDS:
            return '3gp'
        return 'mp4'  # isom, mp41, mp42, M4V, avc1, ...
    return None


def vet_evidence_file(uploaded):
    """Checks an uploaded evidence file and renames it to a random,
    safe name. Returns (file, None) when acceptable, or (None, message)
    when it must be refused. The stored name is a fresh UUID plus the
    extension chosen from the real content — the client's filename is
    never used, so it can't carry a path, a script extension, or give
    anyone a guessable URL."""
    header = uploaded.read(16)
    uploaded.seek(0)
    extension = sniff_extension(header)
    if extension is None:
        return None, (
            'Unsupported evidence file. Please attach a photo '
            '(JPG, PNG, GIF, WebP, HEIC) or a video (MP4, MOV, 3GP, WebM, AVI).'
        )
    uploaded.name = f'{uuid.uuid4().hex}.{extension}'
    return uploaded, None
