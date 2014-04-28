File.dirname(__FILE__).tap do |supermarket|
  Dir[File.join(supermarket, 'community_site', '*_record.rb')].map do |file|
    file.split(File::SEPARATOR).last.split('.').first
  end.each do |record_type|
    require "supermarket/community_site/#{record_type}"
  end
end
