-- 测试表结构
CREATE TABLE `voice_cnt` (
  `row_number` bigint(20) NOT NULL AUTO_INCREMENT,
  `calling_party_number` varchar(40) NOT NULL,
  `called_party_number` varchar(40) NOT NULL,
  `cnt_duration` decimal(10,2) NOT NULL,
  `cnt_call` int(10) NOT NULL,
  PRIMARY KEY (`row_number`)
) ENGINE=InnoDB AUTO_INCREMENT=1 DEFAULT CHARSET=utf8

CREATE TABLE `id_table` (
  `number` bigint(20) NOT NULL,
  PRIMARY KEY (`number`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8


-- 测试数据
INSERT INTO voice_cnt (calling_party_number,called_party_number,cnt_duration,cnt_call) VALUES 
('1','2',40.00,3)
,('1','3',40.00,3)
,('1','4',40.00,2)
,('1','6',40.00,1)
,('1','7',40.00,5)
,('2','1',40.00,5)
,('2','4',40.00,7)
,('2','5',40.00,11)
,('2','6',40.00,8)
,('3','1',40.00,3)
;
INSERT INTO voice_cnt (calling_party_number,called_party_number,cnt_duration,cnt_call) VALUES 
('3','2',40.00,4)
,('3','6',40.00,4)
,('4','1',40.00,3)
,('4','2',40.00,2)
,('4','5',40.00,1)
,('5','1',40.00,3)
,('6','2',40.00,4)
,('6','3',40.00,30)
,('6','5',40.00,1)
;

INSERT INTO `sql-learn`.id_table (`number`) VALUES 
(2)
,(4)
;


-- 计算用户子集(id_table)的one hop cnt
SELECT calling_party_number, COUNT(*) as cnt_one_hop
FROM voice_cnt
WHERE calling_party_number IN (
	SELECT number
	FROM id_table
)
GROUP BY calling_party_number;


-- 计算用户子集(id_table)的two hop cnt
SELECT calling_party_number, COUNT(*) as cnt_two_hop
FROM (
	SELECT DISTINCT t1.calling_party_number, t2.called_party_number
	FROM voice_cnt as t1, voice_cnt as t2
	WHERE t1.called_party_number = t2.calling_party_number and 
	  	t2.called_party_number != t1.calling_party_number and 
	  	t2.called_party_number not in (
	  		SELECT called_party_number
	  		FROM voice_cnt
	  		WHERE calling_party_number = t1.calling_party_number
	  	)
) as t3
WHERE calling_party_number IN (
	SELECT number
	FROM id_table
)
GROUP BY calling_party_number;


-- 输出用户子集(id_table)的一度人脉统计值(cnt_one_hop), 二度人脉统计值(cnt_one_hop + cnt_two_hop), 不建议使用，会很慢
SELECT t0.calling_party_number, t0.cnt_one_hop, t4.cnt_two_hop, (t0.cnt_one_hop + t4.cnt_two_hop) as cnt_hop
FROM (
	SELECT calling_party_number, COUNT(*) as cnt_one_hop
	FROM voice_cnt
	WHERE calling_party_number IN (
		SELECT number
		FROM id_table
	)
	GROUP BY calling_party_number) as t0,
	(
		SELECT calling_party_number, COUNT(*) as cnt_two_hop
		FROM (
			SELECT DISTINCT t1.calling_party_number, t2.called_party_number
			FROM voice_cnt as t1, voice_cnt as t2
			WHERE t1.called_party_number = t2.calling_party_number and 
	  		t2.called_party_number != t1.calling_party_number and 
	  		t2.called_party_number not in (
	  			SELECT called_party_number
	  			FROM voice_cnt
	  			WHERE calling_party_number = t1.calling_party_number
	  		)
		) as t3
		WHERE calling_party_number IN (
		SELECT number
		FROM id_table
		)
	GROUP BY calling_party_number) as t4
WHERE t0.calling_party_number = t4.calling_party_number