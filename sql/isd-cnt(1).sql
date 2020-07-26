-- 测试表结构
CREATE TABLE `msc_detail` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT,
  `service_type` varchar(20) DEFAULT NULL,
  `calling_party_number` varchar(40) DEFAULT NULL,
  `called_party_number` varchar(40) DEFAULT NULL,
  `duration` varchar(250) DEFAULT NULL,
  `date_start_charge` varchar(100) DEFAULT NULL,
  `hour_id` varchar(100) DEFAULT NULL,
  `calling_number_bts` varchar(100) DEFAULT NULL,
  `called_number_bts` varchar(100) DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=1 DEFAULT CHARSET=utf8


-- 测试数据
INSERT INTO indosat.msc_detail (service_type,calling_party_number,called_party_number,duration,date_start_charge,hour_id,calling_number_bts,called_number_bts) VALUES 
('MOC','1111','2222','5','20191003 ','2',NULL,NULL)
,('MOC','1111','3333','6','20191003 ','2','a',NULL)
,('MOC','1111','4444','3','20191003 ','11',NULL,NULL)
,('MOC','2222','4444','3','20191003 ','11',NULL,NULL)
,('MOC','2222','1111','3','20191003 ','11',NULL,NULL)
,('MOC','2222','3333','3','20191003 ','11',NULL,NULL)
,('MOC','2222','4444','3','20191003 ','15',NULL,NULL)
,('MOC','3333','5555','3','20191003 ','10',NULL,NULL)
,('MOC','3333','4444','3','20191003 ','11',NULL,NULL)
,('MOC','3333','5555','3','20191003 ','12',NULL,NULL)
;
INSERT INTO indosat.msc_detail (service_type,calling_party_number,called_party_number,duration,date_start_charge,hour_id,calling_number_bts,called_number_bts) VALUES 
('MTC','1111','3333','6','20191003 ','2',NULL,'a')
,('SMSMO','1111','3333','0','20191003 ','2','b',NULL)
,('SMSMO','1111','2222','0','20191003 ','2',NULL,NULL)
,('SMSMO','1111','4444','0','20191003 ','2',NULL,NULL)
,('SMSMO','1111','5555','0','20191003 ','2',NULL,NULL)
,('SMSMO','1111','2222','0','20191003 ','2',NULL,NULL)
,('SMSMT','1111','3333','0','20191003 ','2',NULL,'b')
,('SMSMT','2222','1111','0','20191003 ','2',NULL,NULL)
,('SMSMT','2222','1111','0','20191003 ','2',NULL,NULL)
,('SMSMT','2222','1111','0','20191003 ','2',NULL,NULL)
;
INSERT INTO indosat.msc_detail (service_type,calling_party_number,called_party_number,duration,date_start_charge,hour_id,calling_number_bts,called_number_bts) VALUES 
('SMSMO','3333','1111','0','20191003 ','2','c',NULL)
,('SMSMO','3333','2222','0','20191003 ','2',NULL,NULL)
,('SMSMO','3333','4444','0','20191003 ','2',NULL,NULL)
,('SMSMT','3333','1111','0','20191003 ','2',NULL,'c')
;


-- call isd cnt
select calling_number_lac_new, calling_number_ci_new, count(*) as call_isd_cnt
from (select distinct t1.*
      from msc_detail as t1, msc_detail as t2
      where t1.calling_party_number = t2.calling_party_number and 
      	t1.called_party_number = t2.called_party_number and 
      	t1.service_type = 'MOC' and 
      	t2.service_type = 'MTC' and 
      	t1.hour_id = t2.hour_id and
      	t1.dt_id  = t2.dt_id and
            t1.calling_number_ci_new = t2.called_number_ci_new and
      	t1.calling_number_lac_new = t2.called_number_lac_new) as t
group by calling_number_lac_new, calling_number_ci_new;


-- sms isd cnt
select calling_number_lac_new, calling_number_ci_new, count(*) as msg_isd_cnt
from (select distinct t1.*
      from msc_detail as t1, msc_detail as t2
      where t1.calling_party_number = t2.calling_party_number and 
      	t1.called_party_number = t2.called_party_number and 
      	t1.service_type = 'SMSMO' and 
      	t2.service_type = 'SMSMT' and 
      	t1.hour_id = t2.hour_id and
      	t1.dt_id  = t2.dt_id and
            t1.calling_number_ci_new = t2.called_number_ci_new and
      	t1.calling_number_lac_new = t2.called_number_lac_new) as t
group by calling_number_lac_new, calling_number_ci_new;