class LastFM
  API_ROOT = 'http://ws.audioscrobbler.com/2.0/'
  def initialize(token)
    @token = token
    @albums_cache = {}
  end

  def find_albums(query)
    @albums_cache[query] ||= begin
      albums = JSON.parse(HTTParty.get("#{API_ROOT}?method=album.search&album=#{URI.escape(query)}&api_key=#{@token}&format=json").body)['results']['albummatches']['album']
      albums.map{|a| Album.new(a)}
    end
  end
end

class Album
  attr_reader :name, :artist, :images

  def initialize(json)
    @name = json['name']
    @artist = json['artist']
    @images = {}
    json['image'].each do |img|
      @images[img['size']] = img['#text']
    end
  end
end