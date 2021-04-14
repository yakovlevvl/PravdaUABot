
import Vapor
import NIO
import Telegrammer

final class BotService {
    
    private let bot: Bot
    private let jobsQueue: BasicJobQueue<Chat>
    private var userJobs = [Int64: String]()
    private var userLastArticleId = [Int64: String]()
    private let pravdaService: PravdaService
    
    init(pravdaService: PravdaService) {
        self.pravdaService = pravdaService
        let token = "1772828451:AAGV8RkXjtMPNKAl4PFDDH5b0kCKMeH6Sp4"
        let settings = Bot.Settings(token: token)
        bot = try! Bot(settings: settings)
        jobsQueue = BasicJobQueue<Chat>(bot: bot)
        configure()
    }
    
    private func configure() {
        do {
            let dispatcher = Dispatcher(bot: bot)
            
            let latestCommandHandler = CommandHandler(commands: ["/latest"], callback: latestCommand)
            dispatcher.add(handler: latestCommandHandler)
            
            let startCommandHandler = CommandHandler(commands: ["/start"], callback: startCommand)
            dispatcher.add(handler: startCommandHandler)
            
            let stopCommandHandler = CommandHandler(commands: ["/stop"], callback: stopCommand)
            dispatcher.add(handler: stopCommandHandler)
            
            _ = try Updater(bot: bot, dispatcher: dispatcher).startLongpolling()
            
        } catch {
            print(error.localizedDescription)
        }
    }
    
    private func startCommand(_ update: Update, _ context: BotContext?) throws {
        guard let message = update.message,
              let user = message.from else {
            return
        }
        stopJobIfNeeded(for: user.id)
        let interval = TimeAmount.seconds(600)
        let timerJob = RepeatableJob(
            when: Date(),
            interval: interval,
            context: message.chat
        ) { [weak self] _ in
            self?.sendLatestArticle(message, force: false)
        }
        userJobs[user.id] = timerJob.id
        _ = jobsQueue.scheduleRepeated(timerJob)
    }
    
    private func stopCommand(_ update: Update, _ context: BotContext?) throws {
        guard let message = update.message,
              let user = message.from else {
            return
        }
        stopJobIfNeeded(for: user.id)
    }
    
    private func latestCommand(_ update: Update, _ context: BotContext?) {
        guard let message = update.message else {
            return
        }
        sendLatestArticle(message, force: true)
    }
    
    private func stopJobIfNeeded(for userId: Int64) {
        userLastArticleId[userId] = nil
        if let scheduledJobId = userJobs[userId] {
            if let notFinishedJob = jobsQueue.jobs.first(where: { $0.id == scheduledJobId }) {
                notFinishedJob.scheduleRemoval()
            }
            userJobs.removeValue(forKey: userId)
        }
    }
    
    private func sendLatestArticle(_ message: Message, force: Bool) {
        _ = pravdaService.getLatestArticle().flatMapThrowing { [weak self] article in
            guard let self = self,
                  let user = message.from,
                  let article = article else {
                return
            }
            if !force,
               self.userLastArticleId[user.id] == article.link {
                return
            }
            let text = "\(article.link)"
            let params = Bot.SendMessageParams(chatId: .chat(message.chat.id), text: text)
            try self.bot.sendMessage(params: params)
            self.userLastArticleId[user.id] = article.link
        }
    }
}

extension Application {
    
    struct BotServiceKey: StorageKey {
        typealias Value = BotService
    }
    
    var botService: BotService {
        get {
            guard let service = self.storage[BotServiceKey.self] else {
                fatalError("Need to register service before using.")
            }
            return service
        }
        set {
            self.storage[BotServiceKey.self] = newValue
        }
    }
}
