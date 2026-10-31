import SwiftUI

public struct CupsizeInfoSheet: View {
    @Environment(\.dismiss) private var dismiss

    public var body: some View {
        ZStack {
            Color(red: 0.08, green: 0.08, blue: 0.09).ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("CUPSIZE")
                            .font(.system(size: 22, weight: .black))
                            .foregroundColor(.white)
                        Text("Краткая справка о группе")
                            .font(.system(size: 13))
                            .foregroundColor(.white.opacity(0.5))
                    }

                    Spacer()

                    Button("Закрыть") {
                        dismiss()
                    }
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(Color(red: 0.91, green: 0.835, blue: 1.0))
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 10)

                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        Text("CUPSIZE — российская группа из Ярославля, играющая смесь гранжа, гаражного рока и абсурдной иронии. Название переводится как «Размер чашечки лифчика». Свой стиль музыканты называют «гаражной залупой», «компьютерным роком», «ПМС-гранжем» или «музыкой сюра».")
                            .font(.system(size: 14))
                            .lineSpacing(4)
                            .foregroundColor(.white.opacity(0.8))

                        sectionTitle("Текущий состав:")
                        bullet("Николай Мамаев (Лина Лифонова, род. 16 июля 2003) — фронтмен, вокалист, автор песен, основатель.")
                        bullet("Ярослав Макаренко — бас-гитара.")
                        bullet("Сергей Крылов (Серега КПЗ) — барабанщик (с 2023 года).")
                        bullet("Андрей Колесов — второй гитарист.")

                        sectionTitle("Бывший состав:")
                        bullet("Андрей Калинин — гитара.")
                        bullet("Аркадий — барабаны.")
                        bullet("Семён Куликов — бас-гитара.")

                        sectionTitle("Команда:")
                        bullet("Александр Пташинский (Птаха) — звукорежиссёр, «человек, который всё сводит».")

                        sectionTitle("Дискография:")
                        bullet("2023 — «дели на два», «Как испортить вечеринку?»")
                        bullet("2024 — «кажется, в аду прикольно, но меня выгнали б утром»")
                        bullet("2025 — «в моих легких выросли цветы» (вошёл в топ-20 лучших релизов года по версии The Flow), «неуравновешеннолетниепесни pt.1», «прыгайдуравишлист!»")
                        bullet("2026 — «Заставь меня плакать».")

                        sectionTitle("О музыке и смыслах:")
                        bullet("Свою музыку Коля описывает как «про юмор и иронию». Тексты часто строятся на абсурдных ситуациях из жизни друзей или выдуманных персонажах.")
                        bullet("Термин «ПМС-гранж» родился из-за резкой смены настроения в треках: «Бывает грустно, бывает, чувствую себя агрессивно, и вот так меня постоянно метает».")
                        bullet("Некоторые песни написаны от лица девушек — это расширяет сюжетные возможности.")

                        sectionTitle("Концерты и жизнь группы:")
                        bullet("В 2025 году группа дала больше 70 концертов, включая фестиваль «МТС Live Лето», и собрала 3000 зрителей в Москве.")
                        bullet("На концертах им часто кидают лифчики (из-за названия). Коля относится к этому с юмором: «Для Киркорова цветы, для нас — бюстгальтеры».")

                        sectionTitle("Интересные факты:")
                        bullet("Раньше CUPSIZE был сольным проектом Николая, но с 2024 года превратился в группу.")
                        bullet("Коля долго копил на свою первую гитару. Гитару, на которой он играет сейчас, его друг выкупил у бездомного в США.")
                        bullet("Несмотря на успех, группа остаётся жить и творить в Ярославле.")

                        Text("Информация подготовлена на основе интервью The Flow и открытых источников.")
                            .font(.system(size: 11))
                            .foregroundColor(.white.opacity(0.35))
                            .padding(.top, 10)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 30)
                }
            }
        }
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 14, weight: .bold))
            .foregroundColor(.white)
            .padding(.top, 4)
    }

    private func bullet(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text("•")
                .foregroundColor(.white.opacity(0.5))
            Text(text)
                .font(.system(size: 13))
                .lineSpacing(3)
                .foregroundColor(.white.opacity(0.75))
        }
    }
}
