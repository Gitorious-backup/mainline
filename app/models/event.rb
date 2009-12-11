# encoding: utf-8
#--
#   Copyright (C) 2008 David A. Cuadrado <krawek@gmail.com>
#   Copyright (C) 2009 Nokia Corporation and/or its subsidiary(-ies)
#   Copyright (C) 2008 Johan Sørensen <johan@johansorensen.com>
#   Copyright (C) 2008 Tor Arne Vestbø <tavestbo@trolltech.com>
#
#   This program is free software: you can redistribute it and/or modify
#   it under the terms of the GNU Affero General Public License as published by
#   the Free Software Foundation, either version 3 of the License, or
#   (at your option) any later version.
#
#   This program is distributed in the hope that it will be useful,
#   but WITHOUT ANY WARRANTY; without even the implied warranty of
#   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#   GNU Affero General Public License for more details.
#
#   You should have received a copy of the GNU Affero General Public License
#   along with this program.  If not, see <http://www.gnu.org/licenses/>.
#++

class Event < ActiveRecord::Base

  MAX_COMMIT_EVENTS = 25

  belongs_to :user
  belongs_to :project
  belongs_to :target, :polymorphic => true
  has_many :events, :as => :target do
    def commits
      all(:limit => Event::MAX_COMMIT_EVENTS+1).select{|e|e.action == Action::COMMIT}
    end
  end

  after_create :create_feed_items

  validates_presence_of :user_id, :unless => :user_email_set?

  named_scope :top, {:conditions => ['target_type != ?', 'Event']}

  def self.latest(count)
    Rails.cache.fetch("events:latest_#{count}", :expires_in => 10.minutes) do
      latest_event_ids = Event.find_by_sql(
        ["select id,action,created_at from events " +
         "use index (index_events_on_created_at) where (action != ?) " +
         "order by created_at desc limit ?", Action::COMMIT, count
        ]).map(&:id)
      Event.find(latest_event_ids, :order => "created_at desc",
        :include => [:user, :project, :events])
    end
  end

  def self.latest_in_projects(count, project_ids)
    Rails.cache.fetch("events:latest_in_projects_#{project_ids.join("_")}_#{count}",
        :expires_in => 10.minutes) do
      find(:all, {
          :from => "#{quoted_table_name} use index (index_events_on_created_at)",
          :order => "events.created_at desc", :limit => count,
          :include => [:user, :project, :events],
          :conditions => ['events.action != ? and project_id in (?)',
                          Action::COMMIT, project_ids]
        })
    end
  end

  def build_commit(options={})
    e = self.class.new(options.merge({:action => Action::COMMIT, :project_id => project_id}))
    e.target = self
    return e
  end

  def has_commits?
    return false if self.action != Action::PUSH
    !events.blank? && !events.commits.blank?
  end

  def single_commit?
    return false unless has_commits?
    return events.size == 1
  end

  def kind
    'commit'
  end

  def email=(an_email)
    if u = User.find_by_email_with_aliases(an_email)
      self.user = u
    else
      self.user_email = an_email
    end
  end

  def git_actor
    @git_actor ||= find_git_actor
  end

  # Initialize a Grit::Actor object:
  # If only the email is provided, we will give back anything before @ as name and email as email
  # If both name and email is provided, we will give an Actor with both
  # If a User object, an Actor with name and email
  def find_git_actor
    if user
      Grit::Actor.new(user.fullname, user.email)
    else
      a = Grit::Actor.from_string(user_email)
      if a.email.blank?
        return Grit::Actor.new(a.name.to_s.split('@').first, a.name)
      else
        return a
      end
    end
  end

  def email
    git_actor.email
  end
#
  def actor_display
    git_actor.name
  end

  protected
  def user_email_set?
    !user_email.blank?
  end

  def create_feed_items
    # Find all the watchers of the project
    watcher_ids = self.project.watchers.find(:all, :select => "users.id").map(&:id)
    # Find anyone who's just watching the target, if it's watchable
    if self.target.respond_to?(:watchers)
      watcher_ids += self.target.watchers.find(:all, :select => "users.id").map(&:id)
    end
    watcher_ids.uniq!
    return if watcher_ids.blank?

    # Build a FeedItem for all the users interested in this events
    sql_values = watcher_ids.map do |an_id|
      "(#{an_id}, #{self.id}, '#{self.created_at.to_s(:db)}', '#{self.created_at.to_s(:db)}')"
    end
    sql = %Q{INSERT INTO feed_items (watcher_id, event_id, created_at, updated_at)
             VALUES #{sql_values.join(',')}}
    ActiveRecord::Base.connection.execute(sql)
  end
end
