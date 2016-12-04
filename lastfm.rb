class LastFM
  BRACES_RE1 = /(.+)(\(.+\))/
  BRACES_RE2 = /(.+)(\[.+\])/
  API_ROOT = 'http://ws.audioscrobbler.com/2.0/'

  def initialize(token)
    @token = token
    @albums_cache = {}
    @top_albums_cache = {}
  end

  def get_album(artist, album_name)
    albums = find_albums(album_name)
    if_has_match_album(albums, artist, album_name) do |album|
      return album
    end
    # Album not found, maybe we have name like "Album (special edition)"? Trying to remove text in braces...
    case album_name
    when BRACES_RE1 then return get_album(artist, album_name.gsub(BRACES_RE1, '\1').strip)
    when BRACES_RE2 then return get_album(artist, album_name.gsub(BRACES_RE2, '\1').strip)
    end
    # Ok, really difficult case, let's find by artist's top albums
    albums = find_top_albums(artist)
    if_has_match_album(albums, artist, album_name) do |album|
      return album
    end
    nil
  end

  private


  def if_has_match_album(albums, artist, album_name)
    albums.each do |album|
      if simplify_string(album.name) == simplify_string(album_name) && simplify_string(album.artist) == simplify_string(artist) && album.large_image != ''
        yield album
      end
    end
  end

  def simplify_string(s)
    s.strip.downcase.gsub('ä','a').gsub('ö','o').gsub('ü','u') # Motorhead and so on
  end

  def find_albums(query)
    @albums_cache[query] ||= begin
      albums = JSON.parse(HTTParty.get("#{API_ROOT}?method=album.search&album=#{URI.escape(query)}&api_key=#{@token}&format=json").body)['results']['albummatches']['album']
      albums.map{|a| Album.new(a)}
    end
  end

  def find_top_albums(artist)
    @top_albums_cache[artist] ||= begin
      albums = JSON.parse(HTTParty.get("#{API_ROOT}?method=artist.getTopAlbums&artist=#{URI.escape(artist)}&api_key=#{@token}&format=json").body)["topalbums"]["album"]
      albums.map{|a| Album.new(a)}
    end
  end
end

class Album
  attr_reader :name, :artist, :images, :large_image

  def initialize(json)
    @name = json['name']
    if json['artist'].is_a?(Hash)
      @artist = json['artist']['name']
    else
      @artist = json['artist']
    end
    @images = {}
    json['image'].each do |img|
      @images[img['size']] = img['#text']
    end
    @large_image = @images['extralarge']
  end
end