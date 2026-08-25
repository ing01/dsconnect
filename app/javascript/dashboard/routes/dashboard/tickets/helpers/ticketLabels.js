// `components-next/label/Label.vue` validates `color` against this exact list and
// silently renders no background for anything else - which is how `green` and
// `violet` ended up producing invisible status badges across the module.
export const LABEL_COLORS = ['slate', 'amber', 'teal', 'ruby', 'blue', 'iris'];

export const STATUS_LABEL_COLORS = {
  open: 'blue',
  resolved: 'teal',
  closed: 'slate',
};

export const PRIORITY_LABEL_COLORS = {
  low: 'slate',
  medium: 'blue',
  high: 'amber',
  urgent: 'ruby',
};

export const statusColor = status => STATUS_LABEL_COLORS[status] || 'slate';

export const priorityColor = priority =>
  PRIORITY_LABEL_COLORS[priority] || 'slate';
