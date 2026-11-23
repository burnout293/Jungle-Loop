# Jungle Loop (0.53) : le moteur web sans la 3D (le jeu n'en a pas besoin) ni ce qu'il n'utilise pas, compilé
# depuis les sources de Godot 4.7.2 (la version de l'éditeur) avec Emscripten 4.0.20 et SCons, installés dans
# C:\Users\Buly\godot-build (src\godot-4.7.2-stable, emsdk, venv-root\venv). Environ 10 minutes.
# Résultat : bin\godot.web.template_release.wasm32.nothreads.zip, à copier dans export\templates\ et à donner au
# préréglage Web (export_presets.cfg, custom_template/release). Moteur 25,6 Mo au lieu de 39,5 Mo (optimize=size ;
# 37,3 Mo en optimize=speed). 0.53 : pas utilisé, il démarre en ~4 s contre ~1,5 s pour le modèle officiel. Gardés : WebRTC (à deux, la course), mbedtls (le mot de passe du debug),
# regex, mp3, ogg, vorbis, webp, svg, le serveur de texte avancé (polices variables).
#   powershell -File tools\build_web_template.ps1
$ErrorActionPreference = 'Continue'
$B = 'C:\Users\Buly\godot-build'
& "$B\emsdk\emsdk_env.ps1" | Out-Null
Set-Location "$B\src\godot-4.7.2-stable"
$opts = @('platform=web', 'target=template_release', 'threads=no', 'optimize=size', 'lto=full', '-j8',
  'disable_3d=yes', 'disable_physics_2d=yes', 'disable_physics_3d=yes', 'disable_navigation_2d=yes', 'disable_navigation_3d=yes', 'disable_xr=yes',
  'module_csg_enabled=no', 'module_gridmap_enabled=no', 'module_gltf_enabled=no', 'module_fbx_enabled=no', 'module_openxr_enabled=no',
  'module_webxr_enabled=no', 'module_mobile_vr_enabled=no', 'module_raycast_enabled=no', 'module_theora_enabled=no', 'module_upnp_enabled=no',
  'module_enet_enabled=no', 'module_camera_enabled=no', 'module_lightmapper_rd_enabled=no', 'module_xatlas_unwrap_enabled=no',
  'module_vhacd_enabled=no', 'module_meshoptimizer_enabled=no', 'module_msdfgen_enabled=no', 'module_jolt_physics_enabled=no',
  'module_godot_physics_3d_enabled=no', 'module_godot_physics_2d_enabled=no', 'module_navigation_2d_enabled=no', 'module_navigation_3d_enabled=no',
  'module_noise_enabled=no', 'module_websocket_enabled=no', 'module_jsonrpc_enabled=no', 'module_interactive_music_enabled=no',
  'module_basis_universal_enabled=no', 'module_ktx_enabled=no', 'module_dds_enabled=no', 'module_tga_enabled=no', 'module_hdr_enabled=no',
  'module_jpg_enabled=no', 'module_bmp_enabled=no', 'module_tinyexr_enabled=no', 'module_visual_shader_enabled=no', 'module_objectdb_profiler_enabled=no')
& "$B\venv-root\venv\Scripts\scons.exe" @opts 2>&1 | Select-Object -Last 40
Get-ChildItem bin | Select-Object Name, Length
