import XCTest
@testable import RussianSignLanguageDictionary

final class ErrorMessageMapperTests: XCTestCase {
    func testMapsAllSignRepositoryErrors() {
        XCTAssertEqual(ErrorMessageMapper.message(for: SignRepositoryError.fileNotFound), "Не удалось загрузить данные")
        XCTAssertEqual(ErrorMessageMapper.message(for: SignRepositoryError.unableToReadFile), "Ошибка чтения файла")
        XCTAssertEqual(ErrorMessageMapper.message(for: SignRepositoryError.invalidDataFormat), "Неверный формат данных")
        XCTAssertEqual(
            ErrorMessageMapper.message(for: SignRepositoryError.noDataAvailable),
            "Для первого запуска приложения необходимо подключение к интернету. После загрузки данных приложение будет работать офлайн."
        )
        XCTAssertTrue(
            ErrorMessageMapper.message(for: SignRepositoryError.decodingError(TestError.sample))
                .contains("Ошибка обработки данных:")
        )
    }

    func testMapsAllVideoRepositoryErrors() {
        XCTAssertEqual(ErrorMessageMapper.message(for: VideoRepositoryError.invalidURL), "Неверный URL видео")
        XCTAssertEqual(ErrorMessageMapper.message(for: VideoRepositoryError.downloadFailed), "Не удалось загрузить видео")
        XCTAssertEqual(
            ErrorMessageMapper.message(for: VideoRepositoryError.videoNotCached),
            "Видео недоступно в офлайн-режиме. Добавьте жест в избранное для просмотра без интернета."
        )
        XCTAssertEqual(
            ErrorMessageMapper.message(for: VideoRepositoryError.noInternetConnection),
            "Нет подключения к интернету. Для просмотра этого видео необходимо подключение к сети."
        )
    }

    func testMapsAllSyncErrors() {
        XCTAssertEqual(
            ErrorMessageMapper.message(for: SyncError.noInternet),
            "Нет подключения к интернету. Проверьте соединение и попробуйте снова."
        )
        XCTAssertEqual(
            ErrorMessageMapper.message(for: SyncError.serverUnavailable),
            "Сервер временно недоступен. Приложение работает на сохранённых данных."
        )
        XCTAssertEqual(
            ErrorMessageMapper.message(for: SyncError.serverError(503)),
            "Ошибка сервера: 503. Попробуйте позже."
        )
        XCTAssertEqual(
            ErrorMessageMapper.message(for: SyncError.invalidResponse),
            "Неверный ответ сервера. Попробуйте позже."
        )
        XCTAssertTrue(
            ErrorMessageMapper.message(for: SyncError.networkError(TestError.sample))
                .contains("Ошибка сети:")
        )
        XCTAssertTrue(
            ErrorMessageMapper.message(for: SyncError.decodingError(TestError.sample))
                .contains("Ошибка обработки данных:")
        )
    }

    func testMapsAllCacheErrors() {
        XCTAssertEqual(
            ErrorMessageMapper.message(for: CacheError.unableToAccessDocumentsDirectory),
            "Не удалось получить доступ к директории документов"
        )
        XCTAssertTrue(
            ErrorMessageMapper.message(for: CacheError.unableToSave(TestError.sample))
                .contains("Ошибка сохранения кеша:")
        )
        XCTAssertTrue(
            ErrorMessageMapper.message(for: CacheError.unableToLoad(TestError.sample))
                .contains("Ошибка загрузки кеша:")
        )
    }

    func testMapsAllVideoCacheErrors() {
        XCTAssertEqual(ErrorMessageMapper.message(for: VideoCacheError.invalidURL), "Невалидный URL видео")
        XCTAssertEqual(
            ErrorMessageMapper.message(for: VideoCacheError.cacheDirectoryNotAvailable),
            "Директория кеша недоступна"
        )
        XCTAssertEqual(
            ErrorMessageMapper.message(for: VideoCacheError.sessionNotConfigured),
            "Внутренняя ошибка: сессия загрузки не настроена"
        )
        XCTAssertEqual(ErrorMessageMapper.message(for: VideoCacheError.downloadFailed), "Не удалось загрузить видео")
        XCTAssertEqual(ErrorMessageMapper.message(for: VideoCacheError.fileNotFound), "Файл видео не найден в кеше")
    }

    func testMapsAllSBERTSearchErrors() {
        XCTAssertEqual(
            ErrorMessageMapper.message(for: SBERTSearchError.invalidResponse),
            "Неверный формат ответа от сервера поиска"
        )
        XCTAssertEqual(
            ErrorMessageMapper.message(for: SBERTSearchError.httpError(statusCode: 500)),
            "Ошибка сети: 500. Попробуйте позже."
        )
        XCTAssertEqual(
            ErrorMessageMapper.message(for: SBERTSearchError.serverError(code: "VALIDATION_ERROR", message: "Пустой запрос")),
            "Ошибка запроса: Пустой запрос"
        )
        XCTAssertEqual(
            ErrorMessageMapper.message(for: SBERTSearchError.serverError(code: "SEARCH_ERROR", message: "Down")),
            "Семантический поиск временно недоступен. Используется текстовый поиск."
        )
        XCTAssertEqual(
            ErrorMessageMapper.message(for: SBERTSearchError.serverError(code: "OTHER", message: "Oops")),
            "Ошибка поиска: Oops"
        )
        XCTAssertEqual(
            ErrorMessageMapper.message(for: SBERTSearchError.unknown),
            "Неизвестная ошибка при поиске"
        )
    }

    func testMapsAllLessonRepositoryErrors() {
        XCTAssertEqual(
            ErrorMessageMapper.message(for: LessonRepositoryError.noDataAvailable),
            "Данные уроков недоступны. Попробуйте сначала выполнить синхронизацию."
        )
        XCTAssertEqual(ErrorMessageMapper.message(for: LessonRepositoryError.invalidURL), "Неверный адрес видео урока")
        XCTAssertEqual(
            ErrorMessageMapper.message(for: LessonRepositoryError.noInternetConnection),
            "Нет подключения к интернету. Видео уроков доступно только при наличии интернета."
        )
        XCTAssertEqual(
            ErrorMessageMapper.message(for: LessonRepositoryError.downloadFailed),
            "Не удалось загрузить видео урока. Попробуйте позже."
        )
    }

    func testGenericMessageUsesTypedOverloadsWhenPossible() {
        XCTAssertEqual(
            ErrorMessageMapper.message(for: SignRepositoryError.fileNotFound as Error),
            "Не удалось загрузить данные"
        )
        XCTAssertEqual(
            ErrorMessageMapper.message(for: VideoRepositoryError.invalidURL as Error),
            "Неверный URL видео"
        )
        XCTAssertEqual(
            ErrorMessageMapper.message(for: SyncError.invalidResponse as Error),
            "Неверный ответ сервера. Попробуйте позже."
        )
        XCTAssertEqual(
            ErrorMessageMapper.message(for: CacheError.unableToAccessDocumentsDirectory as Error),
            "Не удалось получить доступ к директории документов"
        )
        XCTAssertEqual(
            ErrorMessageMapper.message(for: VideoCacheError.fileNotFound as Error),
            "Файл видео не найден в кеше"
        )
        XCTAssertEqual(
            ErrorMessageMapper.message(for: SBERTSearchError.unknown as Error),
            "Неизвестная ошибка при поиске"
        )
        XCTAssertEqual(
            ErrorMessageMapper.message(for: LessonRepositoryError.invalidURL as Error),
            "Неверный адрес видео урока"
        )
    }

    func testGenericMessageFallsBackForUnknownError() {
        XCTAssertEqual(
            ErrorMessageMapper.message(for: TestError.sample as Error),
            "Произошла ошибка: \(TestError.sample.localizedDescription)"
        )
    }

    private enum TestError: LocalizedError {
        case sample

        var errorDescription: String? {
            "Sample failure"
        }
    }
}
