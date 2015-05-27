require "textacular/searchable"

class Post < ActiveRecord::Base
  include Taggable
  extend Searchable :title, :description

  attr_reader :member_id

  belongs_to :category
  delegate :name, to: :category, prefix: true, allow_nil: true
  belongs_to :user
  belongs_to :organization
  belongs_to :publisher, class_name: "User", foreign_key: "publisher_id"
  # belongs_to :member, class_name: "Member", foreign_key: "user_id"

  has_many :user_members, class_name: "Member", through: :user, source: :members

  has_many :transfers
  has_many :movements, through: :transfers

  default_scope -> { order("posts.updated_at DESC") }

  scope :by_category, ->(cat) { where(category_id: cat) if cat }
  scope :by_organization, ->(org) { where(organization_id: org) if org }

  scope :of_active_members, -> do
    with_member.where("members.active")
  end

  scope :with_member, -> {
    joins("JOIN members USING (user_id, organization_id)").
      select("posts.*, members.member_uid as member_uid")
  }

  scope :active, -> {
    where(active: true)
  }

  scope :fuzzy_and_tags, ->(s) {
    from("
    (
      (
        #{Post.fuzzy_search(s).to_sql}
      ) union(
        #{Post.tagged_with_rank(s).to_sql}
      )
    ) #{Post.table_name}")
  }

  scope :from_last_week, -> {
    where(created_at: (1.week.ago.beginning_of_day...DateTime.now.end_of_day))
  }

  validates :user, presence: true
  validates :category, presence: true

  def to_s
    title
  end

  # will read the member_uid if it has been returned by the query, otherwise
  # don't complain and return nil.
  #
  # To ensure the presence of the attribute, use the `with_member` scope
  def member_uid
    read_attribute(:member_uid) if has_attribute?(:member_uid)
  end

  def active?
    user && user.member(organization).try(:active) && active
  end
end
