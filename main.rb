#!/bin/env ruby

require 'rubygems'
require 'bundler/setup'

require 'open-uri'
require './lastfm'

Bundler.setup
Bundler.require :default

LFM = LastFM.new('62c4dc6cfb5f1f0ce1ddecfcb1bfffcc')

def download_cover(url, path)
  return path if FileTest.file?(path)
  File.open(path, "wb") do |saved_file|
    open(url, "rb") do |read_file|
      saved_file.write(read_file.read)
    end
  end
  path
end

def get_release(artist, album_name)
  albums = LFM.find_albums(album_name)
  albums.each do |album|
    if album.name.downcase == album_name.downcase && album.artist.downcase == artist.downcase
      return album
    end
  end
  return nil
end

def get_cover(album, tmp)
  url = album.images['extralarge']
  uri = URI.parse(url)

  name = File.join(tmp, File.basename(uri.path))
  download_cover(url, name)
rescue
  nil
end

def process_file(path, tmp)
  TagLib::FLAC::File.open(path) do |file|
    return if file.picture_list.count > 0
    puts "Processing #{path}..."

    tag = file.xiph_comment
    if tag.nil?
      puts 'ERROR: Tags is empty, skipping...'
      return
    end

    fields = tag.field_list_map
    if fields['ALBUM'].nil? || fields['ARTIST'].nil?
      puts 'ERROR: No album or artist tag, sipping'
      return
    end

    artist = fields['ARTIST'][0]
    album = fields['ALBUM'][0]

    release = get_release(artist, album)
    if release.nil?
      puts "ERROR: release not found for #{path}"
      return
    end
    cover_path = get_cover(release, tmp)
    if cover_path.nil?
      puts "ERROR: something goes wrong with #{path}"
      return
    end

    pic = TagLib::FLAC::Picture.new
    pic.type = TagLib::FLAC::Picture::FrontCover
    pic.mime_type = "image/jpeg"
    pic.description = "front"
    pic.width = 300
    pic.height = 300
    pic.data = File.open(cover_path, 'rb') { |f| f.read }
    file.add_picture(pic)
    file.save
  end
end

def escape_glob(s)
  s.gsub(/[\\\{\}\[\]\*\?]/) { |x| "\\"+x }
end

if ARGV.count < 1
  puts "Usage: main.rb <path>"
  exit(1)
end

Dir.mktmpdir do |dir|
  Dir.glob("#{escape_glob(ARGV[0])}/**/*flac").each do |path|
    process_file(path, dir)
  end
end