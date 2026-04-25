import Testing
@testable import calendar

@Suite("PKCEHelper")
struct PKCEHelperTests {
    @Test func generateVerifierLength() {
        let verifier = PKCEHelper.generateVerifier()
        #expect(verifier.count == 43)
    }

    @Test func generateVerifierIsURLSafe() {
        let verifier = PKCEHelper.generateVerifier()
        #expect(!verifier.contains("+"))
        #expect(!verifier.contains("/"))
        #expect(!verifier.contains("="))
    }

    @Test func generateVerifierUniqueness() {
        let a = PKCEHelper.generateVerifier()
        let b = PKCEHelper.generateVerifier()
        #expect(a != b)
    }

    @Test func generateChallengeIsDeterministic() {
        let verifier = PKCEHelper.generateVerifier()
        let c1 = PKCEHelper.generateChallenge(from: verifier)
        let c2 = PKCEHelper.generateChallenge(from: verifier)
        #expect(c1 == c2)
    }

    @Test func generateChallengeIsURLSafe() {
        let verifier = PKCEHelper.generateVerifier()
        let challenge = PKCEHelper.generateChallenge(from: verifier)
        #expect(!challenge.contains("+"))
        #expect(!challenge.contains("/"))
        #expect(!challenge.contains("="))
    }

    @Test func generateChallengeDiffersFromVerifier() {
        let verifier = PKCEHelper.generateVerifier()
        let challenge = PKCEHelper.generateChallenge(from: verifier)
        #expect(challenge != verifier)
    }
}
