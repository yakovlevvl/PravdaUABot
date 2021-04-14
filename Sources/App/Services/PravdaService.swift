
import Vapor
import SWXMLHash

struct PravdaService {
    
    let client: Client
    
    func getLatestArticle() -> EventLoopFuture<Article?> {
        client.get("https://www.pravda.com.ua/rss/").map { res in
            guard let buffer = res.body else {
                return nil
            }
            let data = String(buffer: buffer)
            let xml = SWXMLHash.parse(data)
            let itemElem = xml["rss"]["channel"]["item"][0]
            let linkElem = itemElem["link"].element?.text
            let titleElem = itemElem["title"].element?.text
            guard let link = linkElem,
                  let title = titleElem else {
                return nil
            }
            return Article(link: link, title: title)
        }
    }
}

extension Application {
    
    var pravdaService: PravdaService {
        .init(client: client)
    }
}
