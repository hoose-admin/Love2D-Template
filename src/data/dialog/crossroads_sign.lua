-- Crossroads roadside sign — nudges the player toward Greenpath and the dash.
-- Data only; rendering is loveui's dialog_box widget.

return {
  id      = 'crossroads_sign',
  speaker = 'Weathered Sign',
  lines = {
    'To the east, the path descends into Greenpath.',
    'Travelers speak of a cloak pale as moth-wing, left on a pedestal there.',
    'Those who wear it say the widest gaps shrink to a single stride.',
  },
  grants = { flag = 'read_crossroads_sign' },
}
