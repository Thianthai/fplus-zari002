@EndUserText.label: 'Incoming Payments - Root Entity'
@AccessControl.authorizationCheck: #NOT_REQUIRED
define root view entity ZR_ZARI002
  as select from ztar_i002_pymt
  composition [0..*] of ZI_ZARI002_ITEM as _Item
{
  key payment_uuid               as PaymentUUID,

      batch_id                   as BatchId,
      salesforce_id              as SalesforceId,
      payment_document_no        as PaymentDocumentNo,
      number_of_items_in_payment as NumberOfItemsInPayment,
      company_code               as CompanyCode,
      posting_date               as PostingDate,
      gl_account                 as GLAccount,
      payment_method             as PaymentMethod,
      sap_payment_method         as SapPaymentMethod,
      cheque_no                  as ChequeNo,
      issue_date                 as IssueDate,
      due_on                     as DueOn,
      cheque_bank_branch         as ChequeBankBranch,
      currency                   as Currency,

      @Semantics.amount.currencyCode: 'Currency'
      rounding_diff              as RoundingDiff,
      @Semantics.amount.currencyCode: 'Currency'
      advance_payment            as AdvancePayment,
      @Semantics.amount.currencyCode: 'Currency'
      fees                       as Fees,
      @Semantics.amount.currencyCode: 'Currency'
      payment_amount             as PaymentAmount,

      status                     as Status,
      salesforce_status          as SalesforceStatus,
      salesforce_message         as SalesforceMessage,

      @Semantics.user.createdBy: true
      created_by                 as CreatedBy,
      @Semantics.systemDateTime.createdAt: true
      created_at                 as CreatedAt,
      @Semantics.user.lastChangedBy: true
      last_changed_by            as LastChangedBy,
      @Semantics.systemDateTime.lastChangedAt: true
      last_changed_at            as LastChangedAt,
      @Semantics.systemDateTime.localInstanceLastChangedAt: true
      local_last_changed_at      as LocalLastChangedAt,

      _Item
}
