@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Incoming Payments - Posting Result'
@Metadata.ignorePropagatedAnnotations: true
// อ่าน ZTAR_I002_PYMT อย่างเดียว ให้หน้า log เห็นผลการ post ล่าสุด
// field พวกนี้ ZARE002 และ ZARI003 เขียนทีหลัง จึงไม่มีใน HDRLOG
// payment ที่ถูก reject ตอนรับข้อมูลไม่มี row ใน table นี้
define view entity ZI_ZARI002_PYMT
  as select from ztar_i002_pymt

  association [0..1] to ZI_ZARI002_POST_STATUS_VH as _PostingStatus
    on $projection.Status = _PostingStatus.Status
{
  key payment_uuid                 as PaymentUUID,

      status                       as Status,

      payment_accounting_document  as PaymentAccountingDocument,
      payment_fiscal_year          as PaymentFiscalYear,
      clearing_accounting_document as ClearingAccountingDocument,
      clearing_fiscal_year         as ClearingFiscalYear,

      submit_message               as SubmitMessage,
      clearing_message             as ClearingMessage,
      reject_batch_id              as RejectBatchId,
      reject_message               as RejectMessage,

      salesforce_status            as SalesforceStatus,
      salesforce_message           as SalesforceMessage,

      _PostingStatus
}
