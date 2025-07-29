# Test Fixes TODO List

## Current Status
- **Test Results:** 672 runs, 40 failures, 105 errors, 2 skips
- **Coverage:** 6.09% (improved from 3.69%)
- **Last Updated:** 2025-07-29

## Fix Categories

### 1. CloudIntegration Uniqueness Conflicts (72 errors) ✅
**Status:** Completed
**Files to fix:**
- [x] `test/controllers/cloud_files_controller_test.rb` - Reduced errors from 32 to 14
- [x] `test/controllers/cloud_integrations_controller_test.rb`
- [x] `test/jobs/cloud_file_import_job_test.rb`
- [x] `test/jobs/cloud_file_sync_job_test.rb`

**Solution:** Add `CloudIntegration.where(user: @user, provider: 'google_drive').destroy_all` before creating in setup

### 2. ViewComponent Path Helper Issues (36 errors) ✅
**Status:** Completed
**Files to fix:**
- [x] `test/components/sub_agent_conversation_component_test.rb` - Fixed route helper name
- [x] `test/components/sub_agent_merge_component_test.rb` - No errors
- [x] Created `test/support/view_component_helper.rb` to include URL helpers

**Solution:** Fixed incorrect route helper name and added ViewComponent configuration

### 3. GoogleDriveService Mock Expectations (6 failures) ✅
**Status:** Completed
**File to fix:**
- [x] `test/services/cloud_services/google_drive_service_test.rb` - All tests passing

**Issues fixed:**
- Fixed mock expectations to match actual method signatures
- Fixed return value keys (:mime_type instead of :content_type)
- Fixed base service to handle hash response from list_files

### 4. CloudIntegration Model Tests (11 failures) ✅
**Status:** Completed
**File to fix:**
- [x] `test/models/cloud_integration_test.rb` - All tests passing

**Issues fixed:**
- Replaced fixture usage with fresh instances to avoid encryption errors
- Fixed uniqueness conflicts by using different users/providers
- Added CloudIntegration.destroy_all in setup

### 5. Missing Test Implementations (2 tests) ⏳
**Status:** Not Started
**Tests to complete:**
- [ ] `test_import_file_should_handle_regular_files`
- [ ] `test_export_document_should_upload_document_to_Drive`

## Progress Tracking

### Completed ✅
- [x] CloudFile model test - recent scope ordering issue
- [x] SubAgentSidebarComponent view tests - UI element issues
- [x] CloudIntegration validation errors in base service tests
- [x] Vite manifest errors (npm install + build)

### Results After Each Fix
1. **Initial:** 672 runs, 41 failures, 143 errors, coverage: 3.69%
2. **After CloudFile fix:** 672 runs, 40 failures, 142 errors
3. **After SubAgentSidebar fix:** 672 runs, 40 failures, 140 errors
4. **After CloudIntegration base fix:** 672 runs, 40 failures, 105 errors
5. **After CloudIntegration controller/job fixes:** 672 runs, 60 failures, 64 errors
6. **After ViewComponent path helper fix:** 672 runs, 73 failures, 47 errors
7. **After CloudIntegration model fixes:** 672 runs, 73 failures, 47 errors
8. **After GoogleDriveService fixes:** 672 runs, 64 failures, 38 errors, coverage: 6.84%
9. **Current:** 672 runs, 64 failures, 23 errors, coverage: 7.35%

## Current Issues Analysis (After Fixes)
- **Major progress:** Reduced errors from 38 to 23 (39% reduction)  
- **CloudFileSyncJob:** Fixed `Net::TimeoutError` issues and ActionCable broadcast problems ✅
- **CloudFileImportJob:** Fixed `nil` title issue in `sanitize_title` method ✅
- **SubAgentConversationComponent:** Still has major issues with attribute errors and missing UI elements
- **Controller tests:** Some 404 errors in CloudIntegrationsController
- **Test implementations:** Some tests are missing assertions

## Expected Results
- Reduce errors from 105 to ~15
- Reduce failures from 40 to ~10
- Improve test coverage to ~8-10%