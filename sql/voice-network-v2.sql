SELECT t1.calling_party_number, t1.cnt_one_hop, (t1.cnt_one_hop + t2.cnt_two_hop) as cnt_hop, t3.cnt_double, t4.cnt_1_2
FROM (
		SELECT calling_party_number, COUNT(*) as cnt_one_hop
		FROM voice_cnt
		GROUP BY calling_party_number
	 ) as t1 LEFT JOIN
	 (
	 	SELECT calling_party_number, COUNT(*) as cnt_two_hop
		FROM (
			SELECT DISTINCT b1.calling_party_number, b2.called_party_number
			FROM voice_cnt as b1, voice_cnt as b2
			WHERE b1.called_party_number = b2.calling_party_number and 
	  		b2.called_party_number != b1.calling_party_number and 
	  		b2.called_party_number not in (
	  			SELECT called_party_number
	  			FROM voice_cnt
	  			WHERE calling_party_number = b1.calling_party_number
	  		)
		) as b3
		GROUP BY calling_party_number
	 ) as t2 ON t1.calling_party_number = t2.calling_party_number LEFT JOIN
	 (
	 	SELECT calling_party_number, COUNT(*) as cnt_double
		FROM (
			SELECT c1.calling_party_number, c1.called_party_number as B, c2.called_party_number as C
			FROM voice_cnt as c1, voice_cnt as c2
			WHERE c1.called_party_number = c2.calling_party_number and c1.calling_party_number = c2.called_party_number
			) as c3
		GROUP BY calling_party_number
	 ) as t3 ON t2.calling_party_number = t3.calling_party_number LEFT JOIN
	 (
	 	SELECT d0.calling_party_number, COUNT(*) as cnt_1_2
		FROM voice_cnt as d0,
	 	(
	 		SELECT DISTINCT d1.calling_party_number, d2.called_party_number
			FROM voice_cnt as d1, voice_cnt as d2
			WHERE d1.called_party_number = d2.calling_party_number and d1.calling_party_number != d2.called_party_number
	 	) as d3
		WHERE d0.calling_party_number = d3.calling_party_number and d0.called_party_number = d3.called_party_number
		GROUP BY d0.calling_party_number
	 ) as t4 ON t3.calling_party_number = t4.calling_party_number
	 
	 
	 