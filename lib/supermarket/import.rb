File.dirname(__FILE__).tap do |supermarket|
  Dir[File.join(supermarket, 'import', '*.rb')].map do |file|
    file.split(File::SEPARATOR).last.split('.').first
  end.each do |name|
    require "supermarket/import/#{name}"
  end
end
