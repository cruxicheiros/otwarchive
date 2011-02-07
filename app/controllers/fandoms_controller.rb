class FandomsController < ApplicationController
  before_filter :load_collection

  def index
    if @collection
      @media = Media.canonical.by_name - [Media.find_by_name(ArchiveConfig.MEDIA_NO_TAG_NAME)]
      if params[:medium_id]
        @medium = Media.find_by_name(params[:medium_id])
        @fandoms = @medium.fandoms.canonical if @medium
      end
      @fandoms = (@fandoms || Fandom).where("filter_taggings.inherited = 0").
                  for_collections_with_count([@collection] + @collection.children)
    elsif params[:medium_id]
      if @medium = Media.find_by_name(params[:medium_id])
        if @medium == Media.uncategorized
          @fandoms = @medium.fandoms.by_name
        else
          @fandoms = @medium.fandoms.canonical.by_name.with_count
        end      
      else
        raise ActiveRecord::RecordNotFound, "Couldn't find media category named '#{params[:medium_id]}'"
      end
    else
      redirect_to media_path(:notice => "Please choose a media category to start browsing fandoms.")
      return
    end
    @fandoms_by_letter = @fandoms.group_by {|f| f.name[0].upcase}
  end
  
  def show
    @fandom = Fandom.find_by_name(params[:id])
    @characters = @fandom.characters.canonical.by_name
  end
  
  def unassigned
    join_string = "LEFT JOIN wrangling_assignments 
                  ON (wrangling_assignments.fandom_id = tags.id) 
                  LEFT JOIN users 
                  ON (users.id = wrangling_assignments.user_id)"
    conditions = "canonical = 1 AND users.id IS NULL"
    unless params[:media_id].blank?
      @media = Media.find_by_name(params[:media_id])
      if @media
        join_string <<  " INNER JOIN common_taggings 
                        ON (tags.id = common_taggings.common_tag_id)" 
        conditions  << " AND common_taggings.filterable_id = #{@media.id} 
                        AND common_taggings.filterable_type = 'Tag'"
      end
    end
    @fandoms = Fandom.joins(join_string).
                      where(conditions).
                      order(params[:sort] == 'count' ? "count DESC" : "name ASC").
                      with_count.
                      paginate(:page => params[:page], :per_page => 250)  
  end
end
