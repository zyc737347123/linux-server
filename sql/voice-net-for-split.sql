SELECT d1.calling_party_number, d2.called_party_number
FROM voice_cnt_part1 as d1, voice_cnt_part2 as d2
WHERE d1.called_party_number = d2.calling_party_number