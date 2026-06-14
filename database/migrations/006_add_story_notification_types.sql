ALTER TABLE notifications DROP CONSTRAINT IF EXISTS notifications_notification_type_check;
ALTER TABLE notifications ADD CONSTRAINT notifications_notification_type_check
  CHECK (notification_type = ANY (ARRAY[
    'request_alert', 'fulfillment_update', 'reward_earned', 'system_message',
    'story_like', 'story_created'
  ]));
