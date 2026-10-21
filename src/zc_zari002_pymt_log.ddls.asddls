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

      // ผลการ post ล่าสุดจาก ZTAR_I002_PYMT
      // ชื่อไม่ซ้ำกับ Status และ SalesforceStatus ของ log ที่เป็นผลการรับข้อมูล
      @ObjectModel.text.element: [ 'PostingStatusText' ]
      @Consumption.valueHelpDefinition: [{ entity: { name: 'ZI_ZARI002_POST_STATUS_VH', element: 'Status' } }]
      @EndUserText.label: 'Posting Status'
      _Payment.Status                     as PostingStatus,
      @EndUserText.label: 'Posting Status'
      _Payment._PostingStatus.StatusText  as PostingStatusText,
      @EndUserText.label: 'Payment Journal Entry'
      _Payment.PaymentAccountingDocument  as PaymentAccountingDocument,
      @EndUserText.label: 'Payment Fiscal Year'
      _Payment.PaymentFiscalYear          as PaymentFiscalYear,
      @EndUserText.label: 'Clearing Journal Entry'
      _Payment.ClearingAccountingDocument as ClearingAccountingDocument,
      @EndUserText.label: 'Clearing Fiscal Year'
      _Payment.ClearingFiscalYear         as ClearingFiscalYear,
      @EndUserText.label: 'Submit Message'
      _Payment.SubmitMessage              as SubmitMessage,
      @EndUserText.label: 'Clearing Message'
      _Payment.ClearingMessage            as ClearingMessage,
      @EndUserText.label: 'Reject Batch ID'
      _Payment.RejectBatchId              as RejectBatchId,
      @EndUserText.label: 'Reject Message'
      _Payment.RejectMessage              as RejectMessage,
      @EndUserText.label: 'Posting Result to SFDC'
      _Payment.SalesforceStatus           as PostingSfdcStatus,
      @EndUserText.label: 'Posting Result Message'
      _Payment.SalesforceMessage          as PostingSfdcMessage,

      CreatedBy,
      CreatedAt,
      LastChangedBy,
      LastChangedAt,
      LocalLastChangedAt,

      /* Associations */
      _ItemLog    : redirected to composition child ZC_ZARI002_ITEM_LOG,
      _MessageLog : redirected to composition child ZC_ZARI002_MSG_LOG
}
