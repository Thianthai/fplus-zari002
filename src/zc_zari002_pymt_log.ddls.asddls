@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Incoming Payments - Header Log'
@Metadata.allowExtensions: true
@Search.searchable: true
@ObjectModel.semanticKey: [ 'RequestId', 'SalesforceId' ]
define root view entity ZC_ZARI002_PYMT_LOG
  provider contract transactional_query
  as projection on ZR_ZARI002_PYMT_LOG
{
  key PaymentUUID,

      @Search.defaultSearchElement: true
      RequestId,
      RequestBody,

      @Search.defaultSearchElement: true
      SalesforceId,
      @Search.defaultSearchElement: true
      PaymentDocumentNo,
      NumberOfItemsInPayment,
      CompanyCode,
      PostingDate,
      GlAccount,
      PaymentMethod,
      SapPaymentMethod,

      ChequeNo,
      IssueDate,
      DueOn,
      ChequeBankBranch,

      Currency,
      RoundingDiff,
      AdvancePayment,
      Fees,
      PaymentAmount,

      Status,
      SalesforceStatus,
      SalesforceMessage,

      CreatedBy,
      CreatedAt,
      LastChangedBy,
      LastChangedAt,
      LocalLastChangedAt,

      /* Associations */
      _ItemLog    : redirected to composition child ZC_ZARI002_ITEM_LOG,
      _MessageLog : redirected to composition child ZC_ZARI002_MSG_LOG
}
