@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Incoming Payments - Message Log'
@Metadata.allowExtensions: true
define view entity ZC_ZARI002_MSG_LOG
  as projection on ZI_ZARI002_MSG_LOG
{
  key MessageUUID,
      PaymentUUID,

      MsgSeq,
      MessageArea,
      SalesforceItemId,
      Status,
      Message,

      LocalLastChangedAt,

      /* Associations */
      _PaymentLog : redirected to parent ZC_ZARI002_PYMT_LOG
}
