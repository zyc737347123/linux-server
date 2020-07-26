-- 通话记录
select distinct calling_party_number, called_party_number, cnt_duration, cnt_call
from (select calling_party_number, called_party_number, sum(duration) as cnt_duration, count(*) as cnt_call, service_type
      from msc_detail
      where duration + 0 > 0 and service_type in ('MOC', 'MTC')
      group by calling_party_number, called_party_number, service_type) as t;


-- 短信记录
select distinct calling_party_number, called_party_number, cnt_sms
from (select calling_party_number, called_party_number, service_type, count(*) as cnt_sms
      from msc_detail
      where service_type in ('SMSMT', 'SMSMO')
      group by calling_party_number, called_party_number, service_type) as t;


-- 查看数据里最早的通话记录
select calling_party_number, called_party_number, date_start_charge
from msc_detail
order by date_start_charge
limit 10;


-- 备份方案
-- select calling_party_number, called_party_number, sum(duration) as cnt_duration, count(*) as cnt_call
-- from (select distinct calling_party_number, called_party_number, duration, date_start_charge, hour_id
-- 	  from msc_detail
--       where service_type in ('MTC', 'MOC')) as t
-- where duration + 0 > 0
-- group by calling_party_number, called_party_number;