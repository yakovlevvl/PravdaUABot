
import Vapor
import NIO
import Telegrammer

final class BotService {
    
    private let bot: Bot
    private let jobsQueue: BasicJobQueue<Chat>
    private var userJobs = [Int64: String]()
    
    init() {
        let token = "1772828451:AAGV8RkXjtMPNKAl4PFDDH5b0kCKMeH6Sp4"
        let settings = Bot.Settings(token: token)
        bot = try! Bot(settings: settings)
        jobsQueue = BasicJobQueue<Chat>(bot: bot)
        configure()
    }
    
    private func configure() {
        do {
            // Handle all incoming messages.
            let dispatcher = Dispatcher(bot: bot)
            
//            let onceTimerStartHandler = CommandHandler(commands: ["/once"], callback: onceTimerStart)
//            dispatcher.add(handler: onceTimerStartHandler)
            
            let repeatedTimerStartHandler = CommandHandler(commands: ["/start"], callback: repeatedTimerStart)
            dispatcher.add(handler: repeatedTimerStartHandler)
            
            let repeatedTimerStopHandler = CommandHandler(commands: ["/stop"], callback: repeatedTimerStop)
            dispatcher.add(handler: repeatedTimerStopHandler)
            
            _ = try Updater(bot: bot, dispatcher: dispatcher).startLongpolling().wait()
            
        } catch {
            print(error.localizedDescription)
        }
    }
    
    private func repeatedTimerStart(_ update: Update, _ context: BotContext?) throws {
        guard let message = update.message,
              let user = message.from else {
            return
        }
        stopJobIfNeeded(for: user.id)
        let interval = TimeAmount.seconds(10)
        let timerJob = RepeatableJob(when: Date(), interval: interval, context: message.chat) { [weak self] chat in
            guard let chat = chat else {
                return
            }
            let params = Bot.SendMessageParams(chatId: .chat(chat.id), text: "Receive text")
            try self?.bot.sendMessage(params: params)
        }
        
        userJobs[user.id] = timerJob.id
        
        _ = jobsQueue.scheduleRepeated(timerJob)
    }
    
    private func repeatedTimerStop(_ update: Update, _ context: BotContext?) throws {
        guard let message = update.message,
              let user = message.from else {
            return
        }
        stopJobIfNeeded(for: user.id)
    }
    
    private func stopJobIfNeeded(for userId: Int64) {
        if let scheduledJobId = userJobs[userId] {
            if let notFinishedJob = jobsQueue.jobs.first(where: { $0.id == scheduledJobId }) {
                notFinishedJob.scheduleRemoval()
            }
            userJobs.removeValue(forKey: userId)
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
