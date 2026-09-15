@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Incoming Payments - Message Log'
@Metadata.ignorePropagatedAnnotations: true
define view entity ZI_ZARI002_MSG_LOG
  as select from ztar_i002_msglog

  association to parent ZR_ZARI002_PYMT_LOG as _PaymentLog
    on $projection.PaymentUUID = _PaymentLog.PaymentUUID
{
      @EndUserText.label: 'Message Log UUID'
  key message_uuid          as MessageUUID,

      @EndUserText.label: 'Payment Log UUID'
      payment_uuid          as PaymentUUID,

      @EndUserText.label: 'Sequence'
      msg_seq               as MsgSeq,
      @EndUserText.label: 'Message Area'
      message_area          as MessageArea,
      @EndUserText.label: 'Salesforce Item ID'
      salesforce_item_id    as SalesforceItemId,
      @EndUserText.label: 'Status'
      status                as Status,
      @EndUserText.label: 'Message'
      message               as Message,

      @Semantics.systemDateTime.localInstanceLastChangedAt: true
      local_last_changed_at as LocalLastChangedAt,

      _PaymentLog
}
