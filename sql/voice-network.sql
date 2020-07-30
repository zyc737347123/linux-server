SELECT t1.calling_party_number, t1.cnt_one_hop, (t1.cnt_one_hop + t2.cnt_two_hop) as cnt_hop, t3.cnt_double, t4.cnt_1_2
FROM (
		SELECT calling_party_number, COUNT(*) as cnt_one_hop
		FROM voice_cnt
		GROUP BY calling_party_number
	 ) as t1,
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
	 ) as t2,
	 (
	 	SELECT calling_party_number, SUM(is_double) as cnt_double
		FROM (
			SELECT c1.calling_party_number, c1.called_party_number as B, c2.called_party_number as C, 
		   		case when c2.called_party_number = c1.calling_party_number then 1 else 0 end as is_double
			FROM voice_cnt as c1, voice_cnt as c2
			WHERE c1.called_party_number = c2.calling_party_number
			) as c3
		GROUP BY calling_party_number
	 ) as t3,
	 (
	 	SELECT calling_party_number, SUM(is_1_2) as cnt_1_2
		FROM (
			SELECT d0.calling_party_number, d0.called_party_number as B, d3.calling_party_number as C, d3.called_party_number as D,
				CASE WHEN d0.called_party_number = d3.called_party_number THEN 1 ELSE 0 END as is_1_2
			FROM voice_cnt as d0,
	 		(
	 			SELECT DISTINCT d1.calling_party_number, d2.called_party_number
				FROM voice_cnt as d1, voice_cnt as d2
				WHERE d1.called_party_number = d2.calling_party_number and d1.calling_party_number != d2.called_party_number
	 		) as d3
			WHERE d0.calling_party_number = d3.calling_party_number
	 	) as d5
		GROUP BY calling_party_number
	 ) as t4
WHERE t1.calling_party_number = t2.calling_party_number and t1.calling_party_number = t3.calling_party_number and t1.calling_party_number = t4.calling_party_number 
	 