-- Read-only diagnostics for the six report rows missing from Combined_DDA_SQL_Procedure.txt.
-- Run in the same Oracle schema/context as the combined query.

WITH missing_refs AS
(
    SELECT '024DAR250912007M' AS internal_ref, 'MF176388' AS report_application_id FROM DUAL
    UNION ALL SELECT '024DAR250912007L', 'MF176388' FROM DUAL
    UNION ALL SELECT '024DAR250811001Z', 'MF178354' FROM DUAL
    UNION ALL SELECT '024DAR2508110020', 'MF178354' FROM DUAL
    UNION ALL SELECT '024DAR241128008E', 'MF160911' FROM DUAL
    UNION ALL SELECT '024DAR241128008D', 'MF160911' FROM DUAL
)
SELECT
    m.internal_ref,
    m.report_application_id,
    (SELECT COUNT(*)
       FROM DDS_OUT_300_CONTROL c300
      WHERE TRIM(c300.SendingInstitutionReferenceNo) = m.internal_ref) AS c300_ref_rows,
    (SELECT COUNT(*)
       FROM DDS_IN_310_CONTROL c310
      WHERE TRIM(c310.SendingInstitutionReferenceNo) = m.internal_ref) AS c310_ref_rows,
    (SELECT COUNT(*)
       FROM DDS_OUT_400_CONTROL c400
      WHERE TRIM(c400.SendingInstitutionReferenceNo) = m.internal_ref) AS c400_ref_rows,
    (SELECT COUNT(*)
       FROM DDS_DDAMAINTENANCE dmain
      WHERE TRIM(dmain.SendingInstitutionReferenceNo) = m.internal_ref) AS maintenance_ref_rows
FROM missing_refs m
ORDER BY m.internal_ref;

-- Shows the combination-branch values and whether its source/application predicate passes.
WITH missing_refs AS
(
    SELECT '024DAR250912007M' AS internal_ref, 'MF176388' AS report_application_id FROM DUAL
    UNION ALL SELECT '024DAR250912007L', 'MF176388' FROM DUAL
    UNION ALL SELECT '024DAR250811001Z', 'MF178354' FROM DUAL
    UNION ALL SELECT '024DAR2508110020', 'MF178354' FROM DUAL
    UNION ALL SELECT '024DAR241128008E', 'MF160911' FROM DUAL
    UNION ALL SELECT '024DAR241128008D', 'MF160911' FROM DUAL
)
SELECT
    m.internal_ref AS report_internal_ref,
    m.report_application_id,
    c300.OUT_300_FILEID,
    c300.UAEDDSFILEID,
    c300.SendingInstitutionReferenceNo AS c300_internal_ref,
    c300.SOURCE AS c300_source,
    c300.DDSFILENAME AS c300_ddsfilename,
    c300.CBRESPONSETYPE AS c300_cbresponsetype,
    c300.CBRESPONSE AS c300_cbresponse,
    d300.PayerIdentificationNoWithOriginator AS d300_application_id,
    d310.MandateReference AS d310_mandate_reference,
    d310.PayerIdentificationNoWithOriginator AS d310_application_id,
    d310.INSTRUCTIONCODE AS d310_instruction_code,
    c310.SendingInstitutionReferenceNo AS c310_internal_ref,
    dmain.SendingInstitutionReferenceNo AS maintenance_internal_ref,
    dmain.SOURCE AS maintenance_source,
    dmain.PayerIdentificationNoWithOriginator AS maintenance_application_id,
    NVL(dmain.SendingInstitutionReferenceNo,
        NVL(c310.SendingInstitutionReferenceNo,
            NVL(c400.SendingInstitutionReferenceNo, c300.SendingInstitutionReferenceNo)))
        AS query_selected_internal_ref,
    NVL(dmain.PayerIdentificationNoWithOriginator,
        NVL(d310.PayerIdentificationNoWithOriginator,
            d300.PayerIdentificationNoWithOriginator))
        AS query_selected_application_id,
    NVL(NVL(dmain.SOURCE, ''), NVL(c300.SOURCE, '')) AS query_selected_source,
    CASE
        WHEN NVL(NVL(dmain.SOURCE, ''), NVL(c300.SOURCE, '')) = 'HFLMS'
          OR NVL(dmain.PayerIdentificationNoWithOriginator,
                 NVL(d310.PayerIdentificationNoWithOriginator,
                     d300.PayerIdentificationNoWithOriginator)) LIKE '%MF%'
        THEN 'PASS'
        ELSE 'FAIL: combination-branch WHERE predicate'
    END AS combination_filter_result,
    nak300.ERRORDESCRIPTION AS nak300_error_description
FROM missing_refs m
LEFT JOIN DDS_OUT_300_CONTROL c300
    ON TRIM(c300.SendingInstitutionReferenceNo) = m.internal_ref
LEFT JOIN DDS_OUT_300_DETAIL d300
    ON c300.OUT_300_FILEID = d300.OUT_300_FILEID
LEFT JOIN DDS_IN_310_DETAIL d310
    ON c300.UAEDDSFILEID = d310.UAEDDSFILEIDFORDAR
LEFT JOIN DDS_IN_310_CONTROL c310
    ON c310.IN_310_FILEID = d310.IN_310_FILEID
LEFT JOIN DDS_DDAMAINTENANCE dmain
    ON d310.MandateReference = dmain.MandateReference
LEFT JOIN DDS_OUT_400_DETAIL d400
    ON d400.MandateReference = dmain.MandateReference
LEFT JOIN DDS_OUT_400_CONTROL c400
    ON d400.OUT_400_FILEID = c400.OUT_400_FILEID
LEFT JOIN DDS_NAKERRORDETAILS nak300
    ON nak300.FILEID = c300.OUT_300_FILEID
    AND nak300.FILETYPE = '300'
ORDER BY m.internal_ref, c300.OUT_300_FILEID;

-- Shows whether a matching maintenance record exists and passes its own eligibility filter.
WITH missing_refs AS
(
    SELECT '024DAR250912007M' AS internal_ref, 'MF176388' AS report_application_id FROM DUAL
    UNION ALL SELECT '024DAR250912007L', 'MF176388' FROM DUAL
    UNION ALL SELECT '024DAR250811001Z', 'MF178354' FROM DUAL
    UNION ALL SELECT '024DAR2508110020', 'MF178354' FROM DUAL
    UNION ALL SELECT '024DAR241128008E', 'MF160911' FROM DUAL
    UNION ALL SELECT '024DAR241128008D', 'MF160911' FROM DUAL
)
SELECT
    m.internal_ref AS report_internal_ref,
    m.report_application_id,
    dmain.SendingInstitutionReferenceNo AS maintenance_internal_ref,
    dmain.PayerIdentificationNoWithOriginator AS maintenance_application_id,
    dmain.MandateReference,
    dmain.SOURCE AS maintenance_source,
    dmain.STATUS AS maintenance_status,
    CASE
        WHEN dmain.PayerIdentificationNoWithOriginator LIKE '%MF%'
          OR dmain.SOURCE = 'HFLMS'
        THEN 'PASS'
        ELSE 'FAIL: maintenance-branch WHERE predicate'
    END AS maintenance_filter_result
FROM missing_refs m
LEFT JOIN DDS_DDAMAINTENANCE dmain
    ON TRIM(dmain.SendingInstitutionReferenceNo) = m.internal_ref
ORDER BY m.internal_ref;
