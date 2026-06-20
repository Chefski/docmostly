import Testing
@testable import docmostly

struct DocmostLabelNameValidatorTests {
    @Test func normalizesLikeDocmostServer() {
        #expect(DocmostLabelNameValidator.normalized(" Product   Launch ") == "product-launch")
        #expect(DocmostLabelNameValidator.normalized("iOS_QA") == "ios_qa")
    }

    @Test func validatesServerPattern() {
        #expect(DocmostLabelNameValidator.isValidPattern("release-2026") == true)
        #expect(DocmostLabelNameValidator.isValidPattern("_internal~draft") == true)
        #expect(DocmostLabelNameValidator.isValidPattern("~draft") == false)
        #expect(DocmostLabelNameValidator.isValidPattern("bad.label") == false)
        #expect(DocmostLabelNameValidator.isValidPattern("") == false)
    }
}
