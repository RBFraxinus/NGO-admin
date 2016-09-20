class Geolocation < ActiveRecord::Base
  has_and_belongs_to_many :projects

  scope :active, lambda {joins(:projects).where("projects.end_date is null or (projects.end_date > ? AND projects.start_date < ?)", Date.today.to_s(:db), Date.today.to_s(:db))}
  scope :closed, lambda {joins(:projects).where("projects.end_date < ?", Date.today.to_s(:db))}
  scope :organizations, lambda{|orgs| joins(:projects).joins('INNER JOIN organizations on projects.primary_organization_id = organizations.id').where(:organizations => {:id => orgs})}

  def self.fetch_all(level, geolocation)
    level ||= 0
    geolocations = Geolocation.where('adm_level = ?', level)
    superlevel  = level.to_i - 1
    geolocations = geolocations.where("g#{superlevel} = ?", geolocation) if geolocation.present? && level.to_i >= 0
    geolocations.order(:name)
  end

  def self.group_by_project_count
    where(:adm_level => 0).
      group("geolocations_projects.geolocation_id").
        order("COUNT(geolocations_projects.project_id) DESC").
        select("geolocations_projects.geolocation_id AS id, COUNT(geolocations_projects.project_id) AS projects_count")
  end
end
