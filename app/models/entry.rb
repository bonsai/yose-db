# frozen_string_literal: true

# Schema-less JSON record (uid uuid, obj jsonb, mtime). Operated via
# Yose::Store; ActiveRecord just holds the primary key convention.
class Entry < ApplicationRecord
  self.primary_key = "uid"
end