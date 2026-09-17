@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Incoming Payments - Header Log'
@Metadata.ignorePropagatedAnnotations: true
define root view entity ZR_ZARI002_PYMT_LOG
  as select from ztar_i002_hdrlog

  composition [0..*] of ZI_ZARI002_ITEM_LOG as _ItemLog
  composition [0..*] of ZI_ZARI002_MSG_LOG  as _MessageLog
{
      @EndUserText.label: 'Payment Log UUID'
  key payment_uuid               as PaymentUUID,

      @EndUserText.label: 'Request ID'
      request_id                 as RequestId,
      @EndUserText.label: 'Request Body (JSON)'
      request_body               as RequestBody,

      @EndUserText.label: 'Salesforce ID'
      salesforce_id              as SalesforceId,
      @EndUserText.label: 'Payment Document No.'
      payment_document_no        as PaymentDocumentNo,
      @EndUserText.label: 'Number of Items'
      number_of_items_in_payment as NumberOfItemsInPayment,
      @EndUserText.label: 'Company Code'
      company_code               as CompanyCode,
      @EndUserText.label: 'Posting Date'
      posting_date               as PostingDate,
      @EndUserText.label: 'G/L Account'
      gl_account                 as GlAccount,
      @EndUserText.label: 'Payment Method'
      payment_method             as PaymentMethod,

      @EndUserText.label: 'Cheque No.'
      cheque_no                  as ChequeNo,
      @EndUserText.label: 'Issue Date'
      issue_date                 as IssueDate,
      @EndUserText.label: 'Due On'
      due_on                     as DueOn,
      @EndUserText.label: 'Bank/Branch'
      cheque_bank_branch         as ChequeBankBranch,

      @EndUserText.label: 'Currency'
      currency                   as Currency,
      @Semantics.amount.currencyCode: 'Currency'
      @EndUserText.label: 'Rounding Difference'
      rounding_diff              as RoundingDiff,
      @Semantics.amount.currencyCode: 'Currency'
      @EndUserText.label: 'Advance Payment'
      advance_payment            as AdvancePayment,
      @Semantics.amount.currencyCode: 'Currency'
      @EndUserText.label: 'Fees'
      fees                       as Fees,
      @Semantics.amount.currencyCode: 'Currency'
      @EndUserText.label: 'Payment Amount'
      payment_amount             as PaymentAmount,

      @EndUserText.label: 'Status'
      status                     as Status,
      @EndUserText.label: 'Salesforce Status'
      salesforce_status          as SalesforceStatus,
      @EndUserText.label: 'Salesforce Message'
      salesforce_message         as SalesforceMessage,

      @Semantics.user.createdBy: true
      @EndUserText.label: 'Created By'
      created_by                 as CreatedBy,
      @Semantics.systemDateTime.createdAt: true
      @EndUserText.label: 'Created At'
      created_at                 as CreatedAt,
      @Semantics.user.lastChangedBy: true
      @EndUserText.label: 'Last Changed By'
      last_changed_by            as LastChangedBy,
      @Semantics.systemDateTime.lastChangedAt: true
      @EndUserText.label: 'Last Changed At'
      last_changed_at            as LastChangedAt,
      @Semantics.systemDateTime.localInstanceLastChangedAt: true
      @EndUserText.label: 'Local Last Changed At'
      local_last_changed_at      as LocalLastChangedAt,

      _ItemLog,
      _MessageLog
}
