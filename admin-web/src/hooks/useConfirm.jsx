import { useCallback, useRef, useState } from 'react';
import ConfirmDialog from '../components/ConfirmDialog';

// Promise-based confirmation modal.
//
//   const [confirm, confirmDialog] = useConfirm();
//   ...
//   if (!(await confirm({ title: 'Delete this?', message: '…' }))) return;
//   ...
//   return (<>{confirmDialog}{/* rest of page */}</>);
export default function useConfirm() {
  const [options, setOptions] = useState(null);
  const resolver = useRef(null);

  const confirm = useCallback((opts = {}) => {
    setOptions(opts);
    return new Promise((resolve) => {
      resolver.current = resolve;
    });
  }, []);

  const settle = useCallback((result) => {
    setOptions(null);
    resolver.current?.(result);
    resolver.current = null;
  }, []);

  const confirmDialog = (
    <ConfirmDialog
      open={Boolean(options)}
      title={options?.title}
      message={options?.message}
      confirmLabel={options?.confirmLabel}
      cancelLabel={options?.cancelLabel}
      onConfirm={() => settle(true)}
      onCancel={() => settle(false)}
    />
  );

  return [confirm, confirmDialog];
}
