# == Schema Information
#
# Table name: sectors
#
#  id   :integer         not null, primary key
#  name :string(255)
#

class Sector < ActiveRecord::Base

  has_and_belongs_to_many :projects

  scope :organizations, lambda{|orgs| joins(:projects).joins('INNER JOIN organizations on projects.primary_organization_id = organizations.id').where(:organizations => {:id => orgs}) }
  scope :active, lambda {joins(:projects).where("projects.end_date > ? AND projects.start_date < ?", Date.today.to_s(:db), Date.today.to_s(:db)).select("DISTINCT sectors.*")}
  scope :closed, lambda {joins(:projects).where("projects.end_date < ?", Date.today.to_s(:db))}

  def donors(site)
    sql="select distinct d.* from organizations as d
    inner join donations as don on d.id=donor_id
    inner join projects_sectors as ps on don.project_id=ps.project_id and ps.sector_id=#{self.id}
    inner join projects as p on ps.project_id=p.id and (p.end_date is null OR p.end_date > now())
    inner join projects_sites as psi on psi.project_id=ps.project_id and psi.site_id=#{site.id}"
    Organization.find_by_sql(sql)
  end

  def self.ordered_by_project_count_for_organization(organization, active = true)
    scope = active ? Project.active.organizations(organization) : Project.closed.organizations(organization)
    ordered_by = scope.
      joins(%q{INNER JOIN "projects_sectors" ON "projects".id = "projects_sectors".project_id}).
      where(%q{"projects_sectors".sector_id = "sectors"."id"}).
      select("COUNT(projects.id)").to_sql
    order("(#{ordered_by}) DESC, sectors.name ASC")
  end

  def self.custom_fields
    columns.map{ |c| c.name }
  end
  # Array of arrays
  # [[region, count], [region, count]]
  def projects_regions(site)
    Region.find_by_sql(
<<-SQL
select r.id,r.name,r.level, r.parent_region_id, r.path, r.country_id,count(ps.*) as count from regions as r
  inner join projects_regions as pr on r.id=pr.region_id and r.level=#{site.level_for_region}
  inner join projects_sites as ps on pr.project_id=ps.project_id and ps.site_id=#{site.id}
  inner join projects as p on ps.project_id=p.id and (p.end_date is null OR p.end_date > now())
  inner join projects_sectors as pse on pse.project_id=ps.project_id and pse.sector_id=#{self.id}
  where r.level = #{site.level_for_region}
  group by r.id,r.name,r.level,r.parent_region_id, r.path, r.country_id  order by count DESC
SQL
    ).map do |r|
      [r, r.count.to_i]
    end
  end

  # Array of arrays
  # [[region, count], [region, count]]
  def projects_countries(site)
    Country.find_by_sql(
<<-SQL
select c.id,c.name,count(ps.*) as count from countries as c
  inner join countries_projects as pr on c.id=pr.country_id
  inner join projects_sites as ps on pr.project_id=ps.project_id and ps.site_id=#{site.id}
  inner join projects as p on ps.project_id=p.id and (p.end_date is null OR p.end_date > now())
  inner join projects_sectors as pse on pse.project_id=ps.project_id and pse.sector_id=#{self.id}
  group by c.id,c.name  order by count DESC
SQL
    ).map do |r|
      [r, r.count.to_i]
    end
  end

  def total_regions(site)
    sql = "select count(distinct(pr.region_id)) as count from projects_regions as pr
    inner join regions as r on pr.region_id=r.id and level=#{site.level_for_region}
    inner join projects as p on p.id=pr.project_id and (p.end_date is null OR p.end_date > now())
    inner join projects_sites as psi on p.id=psi.project_id and psi.site_id=#{site.id}
    inner join projects_sectors as ps on ps.project_id=psi.project_id
    where ps.sector_id=#{self.id}"
    ActiveRecord::Base.connection.execute(sql).first['count'].to_i
  end

  def total_countries(site)
    sql = "select count(distinct(pr.country_id)) as count from countries_projects as pr
    inner join projects as p on p.id=pr.project_id and (p.end_date is null OR p.end_date > now())
    inner join projects_sites as psi on p.id=psi.project_id and psi.site_id=#{site.id}
    inner join projects_sectors as ps on ps.project_id=psi.project_id
    where ps.sector_id=#{self.id}"
    ActiveRecord::Base.connection.execute(sql).first['count'].to_i
  end

  def total_projects(site, location_id = nil)
    if location_id.present?
      if site.navigate_by_country
        location_join = "inner join countries_projects cp on cp.project_id = p.id and cp.country_id = #{location_id.first}"
      else
        location_join = "inner join projects_regions as pr on pr.project_id = p.id and pr.region_id = #{location_id.last}"
      end
    end

    sql = "select count(distinct(ps.project_id)) as count from projects_sectors as ps
    inner join projects as p on p.id=ps.project_id and (p.end_date is null OR p.end_date > now())
    inner join projects_sites as psi on p.id=psi.project_id and psi.site_id=#{site.id}
    #{location_join}
    where ps.sector_id=#{self.id}
          and p.end_date >= current_date
    "
    ActiveRecord::Base.connection.execute(sql).first['count'].to_i
  end

  def projects_for_kml(site)
    sql = "select p.name, ST_AsKML(p.the_geom) as the_geom
    from projects_sectors as ps
    inner join projects as p on p.id=ps.project_id and (p.end_date is null OR p.end_date > now())
    inner join projects_sites as psi on p.id=psi.project_id and psi.site_id=#{site.id}
    where ps.sector_id=#{self.id}"
    ActiveRecord::Base.connection.execute(sql)
  end

  # to get only id and name
  def self.get_select_values
    scoped.select("id,name").order("name ASC")
  end

  def css_class
    if (name.include? 'Agriculture')
       'agriculture'
    elsif (name.include? 'Camp Coordination')
    'camp_coordination'
    elsif (name.include? 'Communication')
    'communication'
    elsif (name.include? 'Disaster')
    'disaster-management'
    elsif (name.include? 'Early Recovery')
    'early_recovery'
    elsif (name.include? 'Energy')
    'energy'
    elsif (name.include? 'Economic Recovery')
    'economic_recovery'
    elsif (name.include? 'Education')
    'education'
    elsif (name.include? 'Emergency Telecommunications')
    'emergency'
    elsif (name.include? 'Environment')
    'environment'
    elsif (name.include? 'Food Aid')
    'food_aid'
    elsif (name.include? 'Food Security')
    'food_security'
    elsif (name.include? 'Health')
    'health'
    elsif (name.include? 'Human')
    'human_rights'
    elsif (name.include? 'Humanitarian')
    'humanitarian-aid'
    elsif (name.include? 'Logistics')
    'logistics'
    elsif (name.include? 'Mining')
    'mining-and-extractive-resources'
    elsif (name.include? 'Non-food')
    'non-food-relief-items'
    elsif (name.include? 'Nutrition')
    'nutrition'
    elsif (name.include? 'Peace')
     'peace_security'
    elsif (name.include? 'Protection')
      'protection'
    elsif (name.include? 'Safety nets')
      'safety-nets'
    elsif (name.include? 'Shelter')
       'shelter'
    elsif (name.include? 'Water')
       'water_sanitation'
    else
       'other'
    end
  end
  def get_profile
    profile = {}
    profile[:name] = self.name
    profile[:projects] = self.projects.select([:id, :name, :budget, :start_date, :end_date, :the_geom])
    profile[:organizations] = Organization.joins('
      INNER JOIN projects on projects.primary_organization_id = organizations.id
      INNER JOIN projects_sectors on projects_sectors.project_id = projects.id
      INNER JOIN sectors on projects_sectors.sector_id = sectors.id
      ').where('sectors.id = ?', self.id).select(['organizations.name','count(projects.id)']).group('organizations.name')
    profile[:donors] = Organization.joins([:donations_made => [:project => :sectors]]).where('sectors.id = ?', self.id).select(['organizations.name','count(projects.id)']).group('organizations.name')
    profile[:countries] = Country.joins([:projects => :sectors]).where('sectors.id = ?', self.id).select(['countries.name','count(projects.id)']).group('countries.name')

    profile
  end

end
