const String demoPlaylistUrl = 'demo://novatv';

/// Lista de demonstração com mídia pública e livre (Blender Foundation / W3C),
/// usada apenas para testar a interface sem conteúdo externo.
const String demoPlaylistContent = '''#EXTM3U
#EXTINF:-1 tvg-id="demo-live" tvg-name="Canal Demo" group-title="Ao Vivo | Demonstração",Canal Demo
https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8
#EXTINF:-1 tvg-id="demo-bbb" tvg-name="Big Buck Bunny (trailer)" group-title="Filmes | Demonstração",Big Buck Bunny (trailer)
https://download.blender.org/peach/trailer/trailer_480p.mov
#EXTINF:-1 tvg-id="demo-ed" tvg-name="Elephants Dream" group-title="Filmes | Demonstração",Elephants Dream
https://download.blender.org/ED/elephantsdream-480-h264-st-aac.mov
#EXTINF:-1 tvg-id="demo-sintel" tvg-name="Sintel (trailer)" group-title="Filmes | Demonstração",Sintel (trailer)
https://media.w3.org/2010/05/sintel/trailer.mp4
#EXTINF:-1 tvg-id="demo-tos" tvg-name="Tears of Steel" group-title="Filmes | Demonstração",Tears of Steel
https://download.blender.org/demo/movies/ToS/tears_of_steel_720p.mov
#EXTINF:-1 tvg-id="demo-serie-1" tvg-name="Série Demo" group-title="Séries | Demonstração",Série Demo T1 E1
https://media.w3.org/2010/05/video/movie_300.mp4
#EXTINF:-1 tvg-id="demo-serie-2" tvg-name="Série Demo" group-title="Séries | Demonstração",Série Demo T1 E2
https://media.w3.org/2010/05/sintel/trailer.mp4
#EXTINF:-1 tvg-id="demo-serie-3" tvg-name="Série Demo" group-title="Séries | Demonstração",Série Demo T1 E3
https://download.blender.org/peach/trailer/trailer_480p.mov
''';
