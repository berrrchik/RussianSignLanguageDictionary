import Foundation

extension Lesson {
    /// Создаёт mock-урок с настраиваемыми параметрами
    static func mock(
        id: String = "lesson_1",
        title: String = "Раздел ЭТО ВАЖНО",
        description: String = "Раздел ЭТО ВАЖНО содержит жесты: Я, ТЫ, ГЛУХОЙ, СЛЫШАЩИЙ, СЛАБОСЛЫШАЩИЙ, ПЕРЕВОДЧИК ЖЕСТОВОГО ЯЗЫКА, ПРИВЕТ, КАК ДЕЛА, СПАСИБО, ПОЖАЛУЙСТА, ПОКА",
        videoUrl: String = "/lessons/lesson-1.mp4",
        order: Int = 1
    ) -> Lesson {
        Lesson(
            id: id,
            title: title,
            description: description,
            videoUrl: videoUrl,
            order: order,
            createdAt: Date(),
            updatedAt: Date()
        )
    }
    
    /// Возвращает массив из 11 mock-уроков с реальными названиями и описаниями
    static func mockLessons() -> [Lesson] {
        [
            Lesson(
                id: "lesson_1",
                title: "Раздел ЭТО ВАЖНО",
                description: "Раздел ЭТО ВАЖНО содержит жесты:\nЯ\nТЫ\nГЛУХОЙ\nСЛЫШАЩИЙ\nСЛАБОСЛЫШАЩИЙ\nПЕРЕВОДЧИК ЖЕСТОВОГО ЯЗЫКА\nПРИВЕТ\nКАК ДЕЛА\nСПАСИБО\nПОЖАЛУЙСТА\nПОКА",
                videoUrl: "/lessons/lesson-1.mp4",
                order: 1,
                createdAt: Date(),
                updatedAt: Date()
            ),
            Lesson(
                id: "lesson_2",
                title: "Раздел СЕМЬЯ",
                description: "Раздел СЕМЬЯ содержит жесты:\nСЕМЬЯ\nМАМА\nПАПА\nБАБУШКА\nДЕДУШКА\nСЫН\nДОЧЬ\nБРАТ\nСЕСТРА\nМУЖ\nЖЕНА\nРОДИТЕЛИ\nДЕТИ\nРЕБЁНОК",
                videoUrl: "/lessons/lesson-2.mp4",
                order: 2,
                createdAt: Date(),
                updatedAt: Date()
            ),
            Lesson(
                id: "lesson_3",
                title: "Раздел ЗНАКОМСТВО",
                description: "Раздел ЗНАКОМСТВО содержит жесты:\nКАК ТЕБЯ/ВАС ЗОВУТ\nМЕНЯ ЗОВУТ\nЗНАКОМИТЬСЯ\nОЧЕНЬ ПРИЯТНО\nСКОЛЬКО ТЕБЕ/ВАМ ЛЕТ\nМНЕ ... ЛЕТ\nГДЕ ТЫ/ВЫ ЖИВЁШЬ/ЖИВЁТЕ\nЯ ЖИВУ",
                videoUrl: "/lessons/lesson-3.mp4",
                order: 3,
                createdAt: Date(),
                updatedAt: Date()
            ),
            Lesson(
                id: "lesson_4",
                title: "Раздел ЧИСЛА",
                description: "Раздел ЧИСЛА содержит жесты:\nЧисла от 1 до 10\nЧисла от 11 до 20\nДесятки (10, 20, 30...)\nСотни и тысячи\nПорядковые числительные",
                videoUrl: "/lessons/lesson-4.mp4",
                order: 4,
                createdAt: Date(),
                updatedAt: Date()
            ),
            Lesson(
                id: "lesson_5",
                title: "Раздел ЦВЕТА",
                description: "Раздел ЦВЕТА содержит жесты:\nКРАСНЫЙ\nОРАНЖЕВЫЙ\nЖЁЛТЫЙ\nЗЕЛЁНЫЙ\nГОЛУБОЙ\nСИНИЙ\nФИОЛЕТОВЫЙ\nЧЁРНЫЙ\nБЕЛЫЙ\nСЕРЫЙ\nКОРИЧНЕВЫЙ\nРОЗОВЫЙ",
                videoUrl: "/lessons/lesson-5.mp4",
                order: 5,
                createdAt: Date(),
                updatedAt: Date()
            ),
            Lesson(
                id: "lesson_6",
                title: "Раздел ВРЕМЯ",
                description: "Раздел ВРЕМЯ содержит жесты:\nВРЕМЯ\nЧАС\nМИНУТА\nСЕКУНДА\nУТРО\nДЕНЬ\nВЕЧЕР\nНОЧЬ\nВЧЕРА\nСЕГОДНЯ\nЗАВТРА\nНЕДЕЛЯ\nМЕСЯЦ\nГОД",
                videoUrl: "/lessons/lesson-6.mp4",
                order: 6,
                createdAt: Date(),
                updatedAt: Date()
            ),
            Lesson(
                id: "lesson_7",
                title: "Раздел ЕДА И НАПИТКИ",
                description: "Раздел ЕДА И НАПИТКИ содержит жесты:\nЕДА\nПИТЬ\nКУШАТЬ\nВОДА\nЧАЙ\nКОФЕ\nСОК\nХЛЕБ\nМОЛОКО\nМЯСО\nРЫБА\nОВОЩИ\nФРУКТЫ",
                videoUrl: "/lessons/lesson-7.mp4",
                order: 7,
                createdAt: Date(),
                updatedAt: Date()
            ),
            Lesson(
                id: "lesson_8",
                title: "Раздел ТРАНСПОРТ",
                description: "Раздел ТРАНСПОРТ содержит жесты:\nТРАНСПОРТ\nМАШИНА\nАВТОБУС\nТРОЛЛЕЙБУС\nТРАМВАЙ\nМЕТРО\nПОЕЗД\nСАМОЛЁТ\nКОРАБЛЬ\nВЕЛОСИПЕД\nТАКСИ",
                videoUrl: "/lessons/lesson-8.mp4",
                order: 8,
                createdAt: Date(),
                updatedAt: Date()
            ),
            Lesson(
                id: "lesson_9",
                title: "Раздел ПРОФЕССИИ",
                description: "Раздел ПРОФЕССИИ содержит жесты:\nПРОФЕССИЯ\nРАБОТАТЬ\nУЧИТЕЛЬ\nВРАЧ\nИНЖЕНЕР\nПРОГРАММИСТ\nПОВАР\nВОДИТЕЛЬ\nПОЛИЦЕЙСКИЙ\nПРОДАВЕЦ\nСТУДЕНТ",
                videoUrl: "/lessons/lesson-9.mp4",
                order: 9,
                createdAt: Date(),
                updatedAt: Date()
            ),
            Lesson(
                id: "lesson_10",
                title: "Раздел ПОГОДА",
                description: "Раздел ПОГОДА содержит жесты:\nПОГОДА\nСОЛНЦЕ\nДОЖДЬ\nСНЕГ\nВЕТЕР\nОБЛАКО\nГРОЗА\nТУМАН\nХОЛОДНО\nТЕПЛО\nЖАРКО",
                videoUrl: "/lessons/lesson-10.mp4",
                order: 10,
                createdAt: Date(),
                updatedAt: Date()
            ),
            Lesson(
                id: "lesson_11",
                title: "Раздел ЭМОЦИИ",
                description: "Раздел ЭМОЦИИ содержит жесты:\nРАДОСТЬ\nГРУСТЬ\nСТРАХ\nУДИВЛЕНИЕ\nЗЛОСТЬ\nЛЮБОВЬ\nСЧАСТЬЕ\nСКУКА\nИНТЕРЕС\nСТЫД",
                videoUrl: "/lessons/lesson-11.mp4",
                order: 11,
                createdAt: Date(),
                updatedAt: Date()
            )
        ]
    }
}
