"""Canonical audit action type constants."""

LOGIN_SUCCESS = "login_success"
LOGIN_FAILURE = "login_failure"
LOGOUT = "logout"
USER_CREATE = "user_create"
USER_UPDATE = "user_update"
USER_DELETE = "user_delete"
ROLE_ASSIGN = "role_assign"
ROLE_REMOVE = "role_remove"
PERMISSION_ASSIGN = "permission_assign"
PERMISSION_REMOVE = "permission_remove"
PROFILE_UPDATE = "profile_update"
PASSWORD_CHANGE = "password_change"
AUDIT_EXPORT = "audit_export"
AVATAR_UPDATE = "avatar_update"
SETTINGS_UPDATE = "settings_update"
CUSTOMER_CREATE = "customer_create"
CUSTOMER_UPDATE = "customer_update"
CUSTOMER_DELETE = "customer_delete"
INVENTORY_CREATE = "inventory_create"
INVENTORY_UPDATE = "inventory_update"
INVENTORY_DELETE = "inventory_delete"
SUPPLIER_CREATE = "supplier_create"
SUPPLIER_UPDATE = "supplier_update"
SUPPLIER_DELETE = "supplier_delete"
STOCK_MOVEMENT_IN = "stock_movement_in"
STOCK_MOVEMENT_OUT = "stock_movement_out"
STOCK_MOVEMENT_ADJUST = "stock_movement_adjust"
TRANSACTION_CREATE = "transaction_create"
TRANSACTION_UPDATE = "transaction_update"
TRANSACTION_CANCEL = "transaction_cancel"
REPORT_EXPORT = "report_export"
WORKFLOW_CREATE = "workflow_create"
WORKFLOW_UPDATE = "workflow_update"
WORKFLOW_SUBMIT = "workflow_submit"
WORKFLOW_ASSIGN = "workflow_assign"
WORKFLOW_APPROVE = "workflow_approve"
WORKFLOW_REJECT = "workflow_reject"
WORKFLOW_COMMENT = "workflow_comment"
WORKFLOW_ESCALATE = "workflow_escalate"
WORKFLOW_ESCALATION_RULE_CREATE = "workflow_escalation_rule_create"
WORKFLOW_ESCALATION_RULE_UPDATE = "workflow_escalation_rule_update"
WALLET_USER_VIEW = "wallet_user_view"
WALLET_TRANSACTION_VIEW = "wallet_transaction_view"

METAL_INVENTORY_UPDATE = "metal_inventory_update"
METAL_INVENTORY_PURCHASE_DEBIT = "metal_inventory_purchase_debit"
SELL_REQUEST_CREATED = "sell_request_created"
SELL_REQUEST_VIEWED = "sell_request_viewed"
SELL_APPROVED = "sell_approved"
SELL_REJECTED = "sell_rejected"
SELL_PAYMENT_PROCESSED = "sell_payment_processed"
SELL_PAYOUT_FAILED = "sell_payout_failed"
ADMIN_PROFILE_UPDATED = "admin_profile_updated"

ALL_ACTIONS = [
    LOGIN_SUCCESS,
    LOGIN_FAILURE,
    LOGOUT,
    USER_CREATE,
    USER_UPDATE,
    USER_DELETE,
    ROLE_ASSIGN,
    ROLE_REMOVE,
    PERMISSION_ASSIGN,
    PERMISSION_REMOVE,
    PROFILE_UPDATE,
    PASSWORD_CHANGE,
    AUDIT_EXPORT,
    AVATAR_UPDATE,
    SETTINGS_UPDATE,
    CUSTOMER_CREATE,
    CUSTOMER_UPDATE,
    CUSTOMER_DELETE,
    INVENTORY_CREATE,
    INVENTORY_UPDATE,
    INVENTORY_DELETE,
    SUPPLIER_CREATE,
    SUPPLIER_UPDATE,
    SUPPLIER_DELETE,
    STOCK_MOVEMENT_IN,
    STOCK_MOVEMENT_OUT,
    STOCK_MOVEMENT_ADJUST,
    TRANSACTION_CREATE,
    TRANSACTION_UPDATE,
    TRANSACTION_CANCEL,
    REPORT_EXPORT,
    WORKFLOW_CREATE,
    WORKFLOW_UPDATE,
    WORKFLOW_SUBMIT,
    WORKFLOW_ASSIGN,
    WORKFLOW_APPROVE,
    WORKFLOW_REJECT,
    WORKFLOW_COMMENT,
    WORKFLOW_ESCALATE,
    WORKFLOW_ESCALATION_RULE_CREATE,
    WORKFLOW_ESCALATION_RULE_UPDATE,
    WALLET_USER_VIEW,
    WALLET_TRANSACTION_VIEW,
    METAL_INVENTORY_UPDATE,
    METAL_INVENTORY_PURCHASE_DEBIT,
    SELL_REQUEST_CREATED,
    SELL_REQUEST_VIEWED,
    SELL_APPROVED,
    SELL_REJECTED,
    SELL_PAYMENT_PROCESSED,
    SELL_PAYOUT_FAILED,
    ADMIN_PROFILE_UPDATED,
]
