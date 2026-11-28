extends SceneTree
# 0.70: the official webrtc-native extension (addons/webrtc_native): outside a browser, a WebRTC connection can be
# made (the coop and the races in the installed versions). Two peers on this machine link up through a data channel.

func _init() -> void:
	var a = WebRTCPeerConnection.new()
	var b = WebRTCPeerConnection.new()
	var ok = a.initialize({}) == OK and b.initialize({}) == OK
	print(("ok   " if ok else "ÉCHEC ") + "une connexion WebRTC se crée hors du navigateur (Coop.supported : %s)" % Coop.supported())
	if not ok:
		print("BILAN webrtc : 1 échec")
		quit()
		return
	var ca = a.create_data_channel("t", {"id": 1, "negotiated": true})
	var cb = b.create_data_channel("t", {"id": 1, "negotiated": true})
	a.session_description_created.connect(func(type, sdp): a.set_local_description(type, sdp); b.set_remote_description(type, sdp))
	b.session_description_created.connect(func(type, sdp): b.set_local_description(type, sdp); a.set_remote_description(type, sdp))
	a.ice_candidate_created.connect(func(m, i, n): b.add_ice_candidate(m, i, n))
	b.ice_candidate_created.connect(func(m, i, n): a.add_ice_candidate(m, i, n))
	a.create_offer()
	var got = ""
	for k in 400:
		await process_frame
		a.poll()
		b.poll()
		if ca.get_ready_state() == WebRTCDataChannel.STATE_OPEN and k % 20 == 0:
			ca.put_packet("bonjour".to_utf8_buffer())
		while cb.get_available_packet_count() > 0:
			got = cb.get_packet().get_string_from_utf8()
		if got != "":
			break
		OS.delay_msec(10)
	print(("ok   " if got == "bonjour" else "ÉCHEC ") + "deux pairs se parlent par un canal de données (%s)" % got)
	print("BILAN webrtc : %s" % ("tout bon" if got == "bonjour" else "échec"))
	quit()
