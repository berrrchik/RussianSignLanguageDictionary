import Foundation
@testable import RussianSignLanguageDictionary

enum TestFixtures {
    static let video = SignVideo(
        id: 1,
        url: "https://example.com/video-1.mp4",
        contextDescription: "Основное видео",
        order: 1,
        createdAt: nil,
        updatedAt: nil
    )

    static let sign = Sign(
        id: "sign-1",
        word: "Привет",
        description: "Тестовый жест",
        categoryId: "category-1",
        videos: [video],
        synonyms: nil
    )

    static let category = Category(
        id: "category-1",
        name: "Базовые слова",
        order: 1,
        signCount: 1,
        icon: "hand.raised",
        color: "#0057B8",
        createdAt: nil,
        updatedAt: nil
    )

    static let lesson = Lesson(
        id: "lesson-1",
        title: "Тестовый урок",
        description: "Описание урока",
        videoUrl: "https://example.com/lesson-1.mp4",
        order: 1,
        createdAt: nil,
        updatedAt: nil
    )

    static let syncMetadata = SyncMetadata(
        lastUpdated: Date(timeIntervalSince1970: 1_700_000_000),
        hasUpdates: true
    )

    static let syncData = SyncData(
        categories: [category],
        signs: [sign],
        lessons: [lesson],
        lastUpdated: Date(timeIntervalSince1970: 1_700_000_000)
    )
}
