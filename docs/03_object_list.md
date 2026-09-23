# ZARI002 — Object List

รายชื่อ repository object ทั้งหมด + ไฟล์ที่จะเกิดใน repo
(`⬜` = ยังไม่สร้าง · `🟨` = ส่ง code ให้ใน chat แล้ว รอผู้ใช้สร้าง/activate บน tenant · `✅` = activate + push ขึ้น repo แล้ว)

> **ABAP object ทุกตัวในเอกสารนี้ผู้ใช้เป็นคนสร้างใน ADT และ push เอง** — Claude ส่ง code ให้ทาง chat
> ไม่เขียนไฟล์ ABAP ลง repo (ดู `CLAUDE.md` §Git) คอลัมน์ "ไฟล์" คือ path ที่ abapGit จะ serialize ไปลง

## Package

ทุก object ลง package **`ZARI002`** ตัวเดียว ไม่มี sub-package · abapGit ผูกที่ `ZARI002` แล้ว

| Package | Folder | Description | Status |
|---------|--------|-------------|--------|
| `ZARI002` | `src/` | Incoming Payments (API) | ✅ |

`.abapgit.xml` ที่ tenant serialize มาใช้ `STARTING_FOLDER = /src/` + `FOLDER_LOGIC = FULL`
เนื่องจาก `ZARI002` เป็น top package ที่ link ไว้และไม่มี sub-package ไฟล์จึงลง `src/` ตรง ๆ
(ถ้าวันหน้าเพิ่ม sub-package ไฟล์ของมันจะไปอยู่ `src/<ชื่อ package เต็ม>/`)

## DDIC

| Object | Type | ไฟล์ | Phase | Status |
|--------|------|------|-------|--------|
| `ZD_REQUEST_STATUS` | Domain (`N`/`C`/`R`/`E`) — transaction status | `src/zd_request_status.doma.xml` | 4 | ✅ |
| `ZE_REQUEST_STATUS` | Data element | `src/ze_request_status.dtel.xml` | 4 | ✅ |
| `ZD_RESPONSE_STATUS` | Domain (`S`/`W`/`E`) — result status ส่งกลับ SFDC | `src/zd_response_status.doma.xml` | 4 | ✅ |
| `ZE_RESPONSE_STATUS` | Data element | `src/ze_response_status.dtel.xml` | 4 | ✅ |
| `ZARI002` | Message class (**39 messages** — `000`–`012` · `100`–`118` · `200`–`205` · `900`) | `src/zari002.msag.xml` | 2 | ✅ |
| `ZARI002/206` | Message `Item &1: document &2 already cleared or reversed` — **ยังไม่ได้สร้าง** สร้างพร้อมตอนเติม logic ของ OQ-08 | `src/zari002.msag.xml` | — | ⬜ |

> **Index ไม่ใช่ไฟล์แยก** — abapGit ฝัง `DD12V` / `DD17V` ไว้ใน `.tabl.xml` ของ table เจ้าของ
> `ZD_*` / `ZE_*` เป็น object กลาง **จงใจไม่ใส่ RICEFW ID ในชื่อ** เพื่อให้ RICEFW อื่น reuse ได้
> `ZD_STATUS` / `ZE_STATUS` ชุดเดิมถูกลบไปแล้ว (2026-08-28) — ไม่มี object กำพร้าค้าง
> `ZTAR_I002_*` ใช้ชื่อที่ผู้ใช้ออกแบบไว้เดิม ไม่เปลี่ยนตาม pattern `ZR_`/`ZC_` ของ project

## Core logic

| Object | Type | ไฟล์ | Phase | Status |
|--------|------|------|-------|--------|
| `ZCX_ZARI002_ERROR` | Exception class | `src/zcx_zari002_error.clas.abap` | 2 | ✅ |
| `ZIF_ZARI002_MASTER_DATA` | Interface — อ่าน master data (mock ได้) | `src/zif_zari002_master_data.intf.abap` | 3 | ✅ |
| `ZCL_ZARI002_MASTER_DATA` | Class — implementation จริงบน released CDS view | `src/zcl_zari002_master_data.clas.abap` | 3 | ✅ |
| `ZCL_ZARI002_VALIDATOR` | Class — validation format/mandatory/consistency · `is_cheque( )` ตัดสินจากคำ · 32 unit test | `src/zcl_zari002_validator.clas.abap` | 3 | ✅ |
| `ZCL_ZARI002_JSON` | Class — parse payload + แปลงชื่อ field 2 ทาง · 9 unit test | `src/zcl_zari002_json.clas.abap` | 3 | ✅ |
| `ZCL_ZARI002_SFDC_RESULT` | Class — POST 1 record ไป `Integration_Log__c` · ขอ token ผ่าน `ZCL_UTILITY` ทุก call · `parse_response( )` + `check_connection( )` · 9 unit test | `src/zcl_zari002_sfdc_result.clas.abap` | 3 | ✅ 2026-09-23 |
| `ZCL_ZARI002_PROCESSOR` | Class — flow 5 ขั้น (parse → normalize → validate → save → callback) · 9 unit test | `src/zcl_zari002_processor.clas.abap` | 3 | ✅ |

ทุก class มีไฟล์คู่: `*.clas.xml` (metadata) + `*.clas.testclasses.abap` (ABAP Unit)

## HTTP service

| Object | Type | ไฟล์ | Phase | Status |
|--------|------|------|-------|--------|
| `ZCL_ZARI002_HTTP` | Handler — `IF_HTTP_SERVICE_EXTENSION` | `src/zcl_zari002_http.clas.abap` | 4 | ✅ |
| `ZARI002_INCOMING_PYMT` | HTTP Service | `src/zari002_incoming_pymt.http.xml` | 4 | ✅ |
| `ZCL_ZARI002_SPIKE` | ⚠️ **ชั่วคราว** — `if_oo_adt_classrun` เคลียร์ 2 table ระหว่างเทส · `DELETE FROM` แบบไม่มี `WHERE` **ห้ามรันบน client ที่มีข้อมูลจริง** · **ลบทิ้งใน Phase 7.6** | `src/zcl_zari002_spike.clas.abap` | 6 | 🟨 temporary |
| `ZCL_ZARI002_UTIL` | ⚠️ **ชั่วคราว** — `if_oo_adt_classrun` ลบ payment ตัวเดียวโดย hardcode `payment_document_no` · ลบเฉพาะ business table **ไม่ลบ log** (ถูกแล้ว log เป็นประวัติ) · **ลบทิ้งใน Phase 7.6** | `src/zcl_zari002_util.clas.abap` | 6 | 🟨 temporary |

> **RAP ถูกถอดออกทั้งหมดเมื่อ 2026-08-31** — CDS view, behavior definition, behavior pool,
> projection view และ behavior projection ถูกลบ · เหตุผลอยู่ใน `01_architecture.md` §2

## Dependency นอก package

| Package | ใช้ทำอะไร |
|---|---|
| `ZBCUTILITY` | `ZCL_UTILITY=>create_sfdc_client( )` / `check_sfdc_connection( )` — ขอ OAuth token ใหม่ทุก call พร้อม `ZCS_SFDC_TOKEN` · `ZBC_SFDC_TOKEN_REST` · `ZCA_SFDC_TOKEN` · repo <https://github.com/Thianthai/fplus-zbcutility> |

## Connectivity

| Object | Type | ไฟล์ | Phase | Status |
|--------|------|------|-------|--------|
| `ZCS_INCOMING_PYMT` | Communication Scenario (inbound) | `src/zcs_incoming_pymt.sco1.xml` | 5 | ✅ |
| `ZARI002_INCOMING_PYMT_HTTP` | Inbound Service | `src/zari002_incoming_pymt_http.sco2.xml` | 5 | ✅ |
| *(hash)* | Service authorization ที่ระบบสร้างให้ | `src/44b031caa406301c29d6134c05f9baht.sush.xml` | 5 | ✅ |
| Communication Scenario (outbound) | สำหรับยิง callback | — | 5 | ⬜ OQ-17 |

> **Communication Scenario เป็น repository object** จึงขึ้น git ด้วย · ส่วน Communication
> System / User / Arrangement เป็น config ใน Fiori **ไม่ขึ้น git** ต้องตั้งใหม่เองในทุกระบบ

## Log & Monitor (Phase 5A — 2026-09-16)

ชุดตารางที่ 2 แยกจากตารางธุรกิจ — เขียน**ทุก payment** ทั้งผ่านและตก · monitor เป็น RAP read-only ตามแบบ ZSDE002

| Object | Type | ไฟล์ | Phase | Status |
|--------|------|------|-------|--------|
| `ZTAR_I002_HDRLOG` | Table — header log = `ZTAR_I002_PYMT` 28 field + `request_body` (JSON ของใบนั้น) | `src/ztar_i002_hdrlog.tabl.xml` | 5A | ✅ |
| `ZTAR_I002_ITMLOG` | Table — item log = `ZTAR_I002_ITEM` ทุก field | `src/ztar_i002_itmlog.tabl.xml` | 5A | ✅ |
| `ZTAR_I002_MSGLOG` | Table — message log 1 row/error · มี `salesforce_item_id` (ZSDE002 ไม่มี) | `src/ztar_i002_msglog.tabl.xml` | 5A | ✅ |
| `ZR_ZARI002_PYMT_LOG` | CDS root view entity — composition → item, msg | `src/zr_zari002_pymt_log.ddls.asddls` | 5A | ✅ |
| `ZI_ZARI002_ITEM_LOG` | CDS interface view — child | `src/zi_zari002_item_log.ddls.asddls` | 5A | ✅ |
| `ZI_ZARI002_MSG_LOG` | CDS interface view — child | `src/zi_zari002_msg_log.ddls.asddls` | 5A | ✅ |
| `ZC_ZARI002_PYMT_LOG` | CDS projection (root) + metadata extension | `src/zc_zari002_pymt_log.ddls.asddls` · `.ddlx.asddlxs` | 5A | ✅ |
| `ZC_ZARI002_ITEM_LOG` | CDS projection + metadata extension | `src/zc_zari002_item_log.ddls.asddls` · `.ddlx.asddlxs` | 5A | ✅ |
| `ZC_ZARI002_MSG_LOG` | CDS projection + metadata extension | `src/zc_zari002_msg_log.ddls.asddls` · `.ddlx.asddlxs` | 5A | ✅ |
| `ZR_ZARI002_PYMT_LOG` | BDEF root — managed · `strict ( 2 )` · read-only · **มี `mapping for` ทุก entity** | `src/zr_zari002_pymt_log.bdef.asbdef` | 5A | ✅ |
| `ZC_ZARI002_PYMT_LOG` | BDEF projection | `src/zc_zari002_pymt_log.bdef.asbdef` | 5A | ✅ |
| `ZBP_R_ZARI002_PYMT_LOG` | Behavior pool — handler ว่าง มีเพราะ `strict` บังคับ `authorization master` | `src/zbp_r_zari002_pymt_log.clas.abap` | 5A | ✅ |
| `ZUI_ZARI002_LOG` | Service definition | `src/zui_zari002_log.srvd.srvdsrv` | 5A | ✅ |
| `ZUI_ZARI002_LOG_O4` | Service binding OData V4 UI | `src/zui_zari002_log_o4.srvb.xml` | 5A | ✅ |
| `ZARI002LOG_UI5R` | Fiori app descriptor (wizard) | `src/zari002log_ui5r.uiad.json` | 5A | ✅ |
| `ZIAM_ZARI002_LOG_EXT` | IAM app | `src/ziam_zari002_log_ext.sia6.xml` | 5A | ✅ |
| `ZBC_ZARI002` | Business catalog + assignment | `src/zbc_zari002.sia1.xml` · `zbc_zari002_0001.sia7.xml` | 5A | ✅ |

`ZCL_ZARI002_PROCESSOR` เพิ่ม method: `save_log` · `to_hdr_log` · `to_itm_log` · `to_msg_log` · `to_request_body` · `to_pretty_json`

## Configuration (ไม่ใช่ repository object — ไม่เข้า repo)

| สิ่งที่ต้องทำ | ที่ไหน | Phase | Status |
|---|---|-------|--------|
| Communication System `SBPA_DEV` | Fiori app | 5 | ✅ |
| ~~`ZARI002_PAYMENT_RESULT_REST`~~ | Outbound Service — **ลบแล้ว 2026-09-23** ย้ายไปใช้ `ZBC_SFDC_TOKEN_REST` ของ `ZBCUTILITY` | 5 | ❌ |
| ~~`ZCS_PAYMENT_RESULT`~~ | Communication Scenario outbound — **ลบแล้ว 2026-09-23** ย้ายไปใช้ `ZCS_SFDC_TOKEN` ของ `ZBCUTILITY` | 5 | ❌ |
| Communication System `SFDC_DEV` | Fiori app — **แชร์ข้าม RICEFW** · outbound user **User ID and Password** = ของ `ZCA_SFDC_TOKEN` ที่ใช้อยู่ · user **OAuth 2.0 (Form Field)** ยังมี ARI001 ใช้ ห้ามลบ | 5 | ✅ |
| ~~Communication Arrangement `ZCA_PAYMENT_RESULT`~~ | Fiori app — **ลบแล้ว 2026-09-23** ย้ายไปใช้ `ZCA_SFDC_TOKEN` ของ `ZBCUTILITY` | 5 | ❌ |
| Communication User `SBPA_DEV` | Fiori app | 5 | ✅ |
| Communication Arrangement `ZCS_INCOMING_PYMT` (client 100) | Fiori app | 5 | ✅ |
| Communication System + Arrangement ขา outbound | Fiori app | 5 | ⬜ |

