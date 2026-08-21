export const MOOD_OPTIONS = [
  { value: 'great', emoji: '😄', labelKey: 'MOOD_CHECKIN.MOODS.GREAT' },
  { value: 'good', emoji: '🙂', labelKey: 'MOOD_CHECKIN.MOODS.GOOD' },
  { value: 'neutral', emoji: '😐', labelKey: 'MOOD_CHECKIN.MOODS.NEUTRAL' },
  { value: 'low', emoji: '🙁', labelKey: 'MOOD_CHECKIN.MOODS.LOW' },
  { value: 'bad', emoji: '😢', labelKey: 'MOOD_CHECKIN.MOODS.BAD' },
];

export const getMoodOption = value =>
  MOOD_OPTIONS.find(option => option.value === value);
