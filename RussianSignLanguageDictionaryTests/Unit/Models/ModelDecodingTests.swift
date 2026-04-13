import XCTest
@testable import RussianSignLanguageDictionary

final class ModelDecodingTests: XCTestCase {
    func testCategoryDecodesSnakeCaseAndOptionalFields() throws {
        let json = """
        {
          "id": "alphabet",
          "name": "Алфавит",
          "order": 1,
          "sign_count": 33,
          "icon": "textformat.abc",
          "color": "#0057B8",
          "created_at": 1700000000,
          "updated_at": 1700000100
        }
        """.data(using: .utf8)!

        let category = try APIJSONDecoder.shared.decode(Category.self, from: json)

        XCTAssertEqual(category.id, "alphabet")
        XCTAssertEqual(category.signCount, 33)
        XCTAssertEqual(category.icon, "textformat.abc")
        XCTAssertEqual(category.color, "#0057B8")
        XCTAssertEqual(category.createdAt, Date(timeIntervalSince1970: 1_700_000_000))
        XCTAssertEqual(category.updatedAt, Date(timeIntervalSince1970: 1_700_000_100))
    }

    func testLessonDecodesWithOptionalDatesAbsent() throws {
        let json = """
        {
          "id": "lesson-1",
          "title": "Базовые жесты",
          "description": "Описание",
          "video_url": "https://example.com/lesson.mp4",
          "order": 2
        }
        """.data(using: .utf8)!

        let lesson = try APIJSONDecoder.shared.decode(Lesson.self, from: json)

        XCTAssertEqual(lesson.id, "lesson-1")
        XCTAssertEqual(lesson.videoUrl, "https://example.com/lesson.mp4")
        XCTAssertNil(lesson.createdAt)
        XCTAssertNil(lesson.updatedAt)
    }

    func testSignDecodesWithOptionalArraysAbsentAndNil() throws {
        let absentArraysJSON = """
        {
          "id": "sign-1",
          "word": "Привет",
          "description": "Описание",
          "category_id": "greetings"
        }
        """.data(using: .utf8)!
        let nullArraysJSON = """
        {
          "id": "sign-2",
          "word": "Пока",
          "description": "Описание",
          "category_id": "greetings",
          "videos": null,
          "synonyms": null
        }
        """.data(using: .utf8)!

        let signWithAbsentArrays = try APIJSONDecoder.shared.decode(Sign.self, from: absentArraysJSON)
        let signWithNilArrays = try APIJSONDecoder.shared.decode(Sign.self, from: nullArraysJSON)

        XCTAssertNil(signWithAbsentArrays.videos)
        XCTAssertNil(signWithAbsentArrays.synonyms)
        XCTAssertNil(signWithNilArrays.videos)
        XCTAssertNil(signWithNilArrays.synonyms)
    }

    func testSignDecodesEmptyArrays() throws {
        let json = """
        {
          "id": "sign-3",
          "word": "Спасибо",
          "description": "Описание",
          "category_id": "greetings",
          "videos": [],
          "synonyms": []
        }
        """.data(using: .utf8)!

        let sign = try APIJSONDecoder.shared.decode(Sign.self, from: json)

        XCTAssertEqual(sign.videos, [])
        XCTAssertEqual(sign.synonyms, [])
    }

    func testSignVideoDecodesSnakeCaseAndOptionalDates() throws {
        let json = """
        {
          "id": 7,
          "url": "https://example.com/video.mp4",
          "context_description": "Основной вариант",
          "order": 3,
          "created_at": 1700000200,
          "updated_at": 1700000300
        }
        """.data(using: .utf8)!

        let video = try APIJSONDecoder.shared.decode(SignVideo.self, from: json)

        XCTAssertEqual(video.id, 7)
        XCTAssertEqual(video.contextDescription, "Основной вариант")
        XCTAssertEqual(video.createdAt, Date(timeIntervalSince1970: 1_700_000_200))
        XCTAssertEqual(video.updatedAt, Date(timeIntervalSince1970: 1_700_000_300))
    }

    func testSignSynonymDecodes() throws {
        let json = """
        {
          "id": "sign-2",
          "word": "Здравствуйте"
        }
        """.data(using: .utf8)!

        let synonym = try APIJSONDecoder.shared.decode(SignSynonym.self, from: json)

        XCTAssertEqual(synonym.id, "sign-2")
        XCTAssertEqual(synonym.word, "Здравствуйте")
    }

    func testSignMetadataDecodesAllOptionalFields() throws {
        let json = """
        {
          "duration": 4.2,
          "file_size": 123456,
          "resolution": "1080x1920",
          "format": "mp4",
          "fps": 30
        }
        """.data(using: .utf8)!

        let metadata = try APIJSONDecoder.shared.decode(SignMetadata.self, from: json)

        XCTAssertEqual(metadata.duration, 4.2)
        XCTAssertEqual(metadata.fileSize, 123456)
        XCTAssertEqual(metadata.resolution, "1080x1920")
        XCTAssertEqual(metadata.format, "mp4")
        XCTAssertEqual(metadata.fps, 30)
    }

    func testSyncMetadataDecodesSecondsSince1970() throws {
        let json = """
        {
          "last_updated": 1700000400,
          "has_updates": true
        }
        """.data(using: .utf8)!

        let metadata = try APIJSONDecoder.shared.decode(SyncMetadata.self, from: json)

        XCTAssertEqual(metadata.lastUpdated, Date(timeIntervalSince1970: 1_700_000_400))
        XCTAssertTrue(metadata.hasUpdates)
    }

    func testSyncDataDecodesNestedModelsAndDates() throws {
        let data = try APIJSONEncoder.shared.encode(TestFixtures.syncData)

        let decoded = try APIJSONDecoder.shared.decode(SyncData.self, from: data)

        XCTAssertEqual(decoded.categories.count, 1)
        XCTAssertEqual(decoded.signs.count, 1)
        XCTAssertEqual(decoded.lessons.count, 1)
        XCTAssertEqual(decoded.lastUpdated, TestFixtures.syncData.lastUpdated)
    }

    func testSBERTSearchResultDecodesSimilarity() throws {
        let json = """
        {
          "id": "sign-1",
          "word": "Привет",
          "similarity": 0.94
        }
        """.data(using: .utf8)!

        let result = try APIJSONDecoder.shared.decode(SBERTSearchResult.self, from: json)

        XCTAssertEqual(result.id, "sign-1")
        XCTAssertEqual(result.word, "Привет")
        XCTAssertEqual(result.similarity, 0.94)
    }

    func testAPIJSONEncoderEncodesSnakeCaseAndSecondsSince1970() throws {
        let category = Category(
            id: "alphabet",
            name: "Алфавит",
            order: 1,
            signCount: 33,
            icon: nil,
            color: nil,
            createdAt: Date(timeIntervalSince1970: 1_700_000_500),
            updatedAt: nil
        )

        let data = try APIJSONEncoder.shared.encode(category)
        let jsonObject = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])

        XCTAssertEqual(jsonObject["sign_count"] as? Int, 33)
        XCTAssertEqual(jsonObject["created_at"] as? Double, 1_700_000_500)
    }

    func testDecoderThrowsForMalformedCategoryType() {
        let json = """
        {
          "id": "alphabet",
          "name": "Алфавит",
          "order": "first",
          "sign_count": 33
        }
        """.data(using: .utf8)!

        XCTAssertThrowsError(try APIJSONDecoder.shared.decode(Category.self, from: json))
    }

    func testDecoderThrowsForMalformedSyncMetadataType() {
        let json = """
        {
          "last_updated": "yesterday",
          "has_updates": true
        }
        """.data(using: .utf8)!

        XCTAssertThrowsError(try APIJSONDecoder.shared.decode(SyncMetadata.self, from: json))
    }
}
