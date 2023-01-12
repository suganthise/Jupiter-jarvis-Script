--psql -h localhost -U postgres -d BNPP_2914 -v v1=364 -f "C:\backup\\test.sql">"c:\backup\test.json"
SELECT row_to_json(forms.*) AS row_to_json
   FROM ( SELECT ( SELECT jsonb_agg(nested_call.*) AS jsonb_agg
                   FROM ( SELECT 
                         '1' as "source-id",
						 'jarvis-tamilnadu' as "source-name",
ci.callid AS system_conversationid,
                            a.agent_userid AS "agent-id",
                            a.cus_id AS "cust-id",
                            a.org_id as "org-id",
                            a.cat_id AS "business-unit-id",
                            a.callcreateddate AS "conversation-date",
                           (EXTRACT (EPOCH FROM startdatetime))::numeric * 1000 AS "conversation-time" 
                           FROM callinfo a
                          WHERE a.callid = ci.callid) nested_call) AS contact_metadata,
            ( SELECT jsonb_agg(nested_contact.*) AS jsonb_agg
                   FROM ( SELECT cm.callduration AS dur,
                            cm.calldurationslabid AS "dur-slab-id",
                            cm.callholdcount AS holds,
                            cm.callhold AS "hold-dur",
                            cm.agentspeechoverlap AS "agent-speech-overlaps",
                            cm.agentspeechoverlapcount AS "agent-speech-overlap",
                             cm.customerspeechoverlap AS "customer-speech-overlaps",
                            cm.customerspeechoverlapcount AS "customer-speech-overlap",
                            cm.agentlongtalk as "agent-long-talk",
                            cm.agentlongtalkcount as "agent-long-talks",
                            cm.customerlongtalk as "customer-long-talk",
                            cm.customerlongtalkcount as "customer-long-talks"
                           FROM callmetasummary cm
                          WHERE cm.callid = ci.callid) nested_contact) AS contact_attributes,
            ( SELECT jsonb_agg(nested_scores.*) AS jsonb_agg
                   FROM ( SELECT cls.score_id,
                            cls.value AS "score-value",
                            vsc.scoreslab_id as "scoreslab-id",
                            vsc.score_name as "score-name",
                            vsc.scoreslab_name as "scoreslab-name",
                            vsc.slab_range as "slab-range",
                            ( SELECT json_agg(nested_scorecomponent.*) AS json_agg
                                   FROM ( SELECT clsr.scorecomponent_id,
  CASE scomp.scorecomptype
   WHEN 'BusinessRule'::text THEN scomp.br_id
   ELSE '-1'::integer
  END AS component_id,
    scomp.scorecomptype AS component_type
   FROM calllevelscorecomponentresult clsr
     JOIN scorecomponent scomp ON scomp.scorecomponent_id = clsr.scorecomponent_id
  WHERE clsr.callid = cls.callid AND clsr.score_id = cls.score_id) nested_scorecomponent) AS scorecomponent
                           FROM calllevelscoreresult cls
                             LEFT JOIN view_score_name vsc ON vsc.score_id = cls.score_id
                          WHERE cls.callid = ci.callid) nested_scores) AS scores,
            ( SELECT jsonb_agg(nested_br.*) AS jsonb_agg
                   FROM ( SELECT brs.br_id as "br-id",
                            brs.brr_value as "br_value",
                            br.br_name as "br-name",
                            ( SELECT json_agg(nested_keyword.*) AS json_agg
                                   FROM ( SELECT cva.keyword_id,
    vbr.keyword_name as "keyword-name",
    cva.startoffset as "start",
    cva.endoffset as "end",
    cva.channel 
   FROM callvoiceattribute cva
     JOIN view_brmap vbr ON vbr.keyword_id = cva.keyword_id AND brs.br_id = vbr.br_id
  WHERE cva.callid = cva.callid) nested_keyword) AS keyword
                           FROM brresult brs
                             JOIN businessrule br ON br.br_id = brs.br_id
                          WHERE brs.callid = ci.callid) nested_br) AS businessrule
           FROM ( SELECT callinfo.callid
                   FROM callinfo) ci
          WHERE ci.callid = :v1) forms(contact_metadata, contact_attributes,scores, businessrule); 