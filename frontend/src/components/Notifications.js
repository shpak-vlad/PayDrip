import React from 'react';
import { toast } from 'sonner';

export function showSuccessNotification(message) {
  toast.success(message);
}

export function showErrorNotification(message) {
  toast.error(message);
}
