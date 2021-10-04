tool
extends EditorImportPlugin

const BitsPerPixel = 2

enum Presets {
  DEFAULT,
  P555,
  P5551,
  PRESET_SIZE
}

enum FORMAT {
  F565,
  F555,
  FORMAT_SIZE
}

func get_preset_name(preset):
  match preset:
      Presets.DEFAULT:
        return "565"
      Presets.P555:
        return "555"
      Presets.P5551:
        return "5551"
      _:
        return "Unknown"

func get_preset_count():
  return Presets.PRESET_SIZE

func get_import_options(preset):
  match preset:
      Presets.DEFAULT:
          return [{
                      "name": "force_format",
                      "default_value": false
                  },
                  {
                    "name": "format",
                    "default_value": FORMAT.F565
                  }]
      _:
          return []

func get_option_visibility(option, options):
  if option == "force_format":
    return true
  if options.force_format and option == "format":
    return true

func get_importer_name():
  return "blk_import_plugin"

func get_visible_name():
  return "BLK Import Plugin"

func get_recognized_extensions():
  return ["blk"]

func get_save_extension():
  return "res"

func get_resource_type():
  return "ImageTexture"

func get_pixel(pixel, format):
  if format == FORMAT.F565:
    var red = (pixel & 0x7c00) >> 10;
    var green = (pixel & 0x03e0) >> 5;
    var blue = pixel & 0x001f;
    return [red * 8, green * 8, blue * 8];
  else:
    var red = (pixel & 0xf800) >> 11;
    var green = (pixel & 0x07e0) >> 5;
    var blue = pixel & 0x001f;
    return [red * 8, green * 4, blue * 8];

func import(source_file, save_path, options, r_platform_variants, r_gen_files):
  var file = File.new()
  var err = file.open(source_file, File.READ)
  if err != OK:
    return err
  
  var myPixelFormat = file.get_32()
  var myTileWidth = file.get_16()
  var myTileHeight = file.get_16()
  var myCount = file.get_16()

  var myBitmaps = [];

  print_debug("format: ", myPixelFormat, "width: ", myTileHeight, "height: ", myTileWidth)

  for i in range(myCount):
    var myOffset = file.get_32()
    var myWidth = file.get_16()
    var myHeight = file.get_16()
    
    myBitmaps.push_back({
      "offset": 4 + myOffset, # account for myCount
      "width": myWidth,
      "height": myHeight
    });

    print_debug("offset: ", myOffset, "width: ", myWidth, "height: ", myHeight);

  var atlas = Image.new()
  atlas.create(myTileWidth * (myBitmaps[0].width), myTileHeight * (myBitmaps[0].height), false, Image.FORMAT_RGBA8)
  
  var image = Image.new()
  image.create(myBitmaps[0].width, myBitmaps[0].height, false, Image.FORMAT_RGBA8)
  var nextSet = 0
  # nextSet = tiley + tilex * myTileHeight
  var i = 0
  for tiley in range(myTileHeight):
    i = nextSet
    for tilex in range(myTileWidth):
      file.seek(myBitmaps[i].offset)

      image.lock()

      for x in range(myBitmaps[i].width):
        for y in range(myBitmaps[i].height):
          var j = myBitmaps[i].width * y + x
          file.seek(myBitmaps[i].offset + (j * 2))
          
          var byte = file.get_16()
          var rgb

          if options.force_format:
            rgb = get_pixel(byte, options.format)
          else:
            rgb = get_pixel(byte, myPixelFormat)
          
          var r = rgb[0]; var g = rgb[1]; var b = rgb[2];
          var color = Color8(r, g, b, 255);

          image.set_pixel(x, y, color)

      image.unlock()
      
      var src = Rect2(Vector2(0, 0), Vector2(myBitmaps[i].width, myBitmaps[i].height))
      atlas.blit_rect(image, src, Vector2(tilex * (myBitmaps[i].width), tiley * (myBitmaps[i].height)))

      i += myTileHeight
    nextSet += 1

  var path = "%s.%s" % [save_path, get_save_extension()]

  r_gen_files.push_back(path)

  var tileset = ImageTexture.new()
  tileset.create_from_image(atlas)

  ResourceSaver.save(path, tileset);

  file.close()
