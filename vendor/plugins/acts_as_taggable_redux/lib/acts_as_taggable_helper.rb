module ActsAsTaggableHelper
  # Create a link to the tag using restful routes and the rel-tag microformat
  def link_to_tag(tag)
    link_to(tag.name, tag_url(tag), :rel => 'tag')
  end
  
  # Generate a tag cloud of the top 100 tags by usage, uses the proposed hTagcloud microformat.
  #
  # Inspired by http://www.juixe.com/techknow/index.php/2006/07/15/acts-as-taggable-tag-cloud/
  # Hacked to shreds by Mark Borkum (mib104@ecs.soton.ac.uk)
  def tag_cloud(limit=100, options = {})
    l_option = limit ? { :limit => limit } : { }
    
    # TODO: add options to specify different limits and sorts
    tags = Tag.find(:all, l_option.merge({ :order => 'taggings_count DESC'})).sort_by(&:name)
    
    return tag_cloud_from_collection(tags, true)
  end
    
  def tag_cloud_from_collection(tags, original=false)
    tags = tags.sort { |a, b|
      a.name <=> b.name
    }
    
    # TODO: add option to specify which classes you want and overide this if you want?
    classes = %w(popular v-popular vv-popular vvv-popular vvvv-popular)
    
    max, min = 0, 0
    tags.each do |tag|
      max = tag.taggings_count if tag.taggings_count > max
      min = tag.taggings_count if tag.taggings_count < min
    end
    
    divisor = ((max - min) / classes.size) + 1
    
    count = 0;
    
    html =    %(<div class="hTagcloud">\n)
    html <<   %(  <ul class="popularity">\n)
    tags.each do |tag|
      html << %(    <li>)
      
      if original
        html << link_to(tag.name, tag_url(tag), :class => classes[(tag.taggings_count - min) / divisor]) 
      else
        html << "<a href='#{tag_url(Tag.find(:first, :conditions => ["name = ?", tag.name]))}' class='#{classes[(tag.taggings_count - min) / divisor]}'>#{tag.name}</a>"
      end
      
      html << %(</li>\n)
      
      count += 1;
      
      if count < tags.length
        html << %(<li> | </li>\n)
      end
    end
    html <<   %(  </ul>\n)
    html <<   %(</div>\n)
  end
end