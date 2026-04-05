import Foundation

/// Maps an expense title string to the most likely ExpenseCategory using keyword matching.
enum CategoryDetector {
    static func detect(from title: String) -> ExpenseCategory? {
        let t = title.lowercased()

        let rules: [(keywords: [String], category: ExpenseCategory)] = [
            // Food & Drink
            (["pizza", "burger", "sushi", "taco", "shawarma", "pho", "ramen",
              "coffee", "tim hortons", "mcdonalds", "mcdonald", "subway", "chipotle",
              "kfc", "wendy", "starbucks", "bubble tea", "boba", "loblaws", "metro",
              "freshmart", "grocery", "superstore", "food", "restaurant", "dinner",
              "lunch", "breakfast", "cafe", "bakery", "bar", "pub", "drinks",
              "beer", "wine", "alcohol", "dominos", "pizza hut", "swiss chalet",
              "harveys", "a&w", "popeyes", "dine", "eat", "meal", "snack",
              "takeout", "takeaway", "delivery", "uber eats", "doordash", "skip"],
             .food),

            // Travel
            (["uber", "lyft", "taxi", "transit", "ttc", "go train", "via rail",
              "flight", "airbnb", "hotel", "motel", "hostel", "parking", "gas",
              "petro", "shell", "esso", "trip", "travel", "bus", "presto",
              "rental car", "zipcar", "bike", "ferry", "greyhound", "car", "tolls",
              "airport", "airline", "porter", "westjet", "air canada", "southwest"],
             .travel),

            // Rent & Home
            (["rent", "hydro", "electricity", "water bill", "internet", "wifi",
              "bell", "rogers", "telus", "shaw", "maintenance", "furniture",
              "ikea", "home depot", "cleaning", "laundry", "apartment",
              "condo", "house", "mortgage", "utilities", "lease", "storage", "moving"],
             .rent),

            // Fun & Entertainment
            (["netflix", "spotify", "disney", "apple tv", "prime video", "hulu",
              "youtube premium", "twitch", "game", "steam", "playstation", "xbox",
              "movie", "cinema", "concert", "ticket", "event", "festival",
              "bowling", "escape room", "arcade", "karaoke", "club", "nightclub",
              "museum", "zoo", "aquarium", "theme park", "ski", "snowboard",
              "camping", "gym", "fitness", "yoga", "class", "golf",
              "sport", "league", "hobby", "art", "craft", "paint night"],
             .fun),

            // Utilities / Other bills
            (["phone bill", "phone plan", "data plan", "subscription", "insurance",
              "textbook", "course", "tuition", "amazon", "walmart", "costco",
              "office", "stationary", "printer", "laptop", "tech", "electronics",
              "apple store", "best buy", "health", "pharmacy", "drugstore",
              "shoppers", "rexall", "medical", "dentist", "haircut", "barber", "salon"],
             .utilities),
        ]

        for rule in rules {
            for keyword in rule.keywords where t.contains(keyword) {
                return rule.category
            }
        }
        return nil
    }
}
