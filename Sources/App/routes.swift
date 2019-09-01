import Vapor

/// Register your application's routes here.
public func routes(_ router: Router) throws {
    // Basic "It works" example
    router.get { req in
        return "It works!"
    }
    
    // Basic "Hello, world!" example
    router.get("hello") { req in
        return "Hello, world!"
    }
    
    /// API part

    let gameMapController = MapsController()
    let gameMapViewController = MapsViewController()
    router.get("maps", use: gameMapController.index)
    router.get("maps", "random", use: gameMapController.random)
    router.get("maps", "seed", String.parameter, use: gameMapController.withSeed)
    router.get("maps", "topseeds", use: gameMapController.topSeeds)
    router.post("maps", use: gameMapController.create)

    router.get("maps", "json", Int.parameter, use: gameMapController.json)
    router.get("maps", "json2", Int.parameter, use: gameMapController.json2)

    
    router.post("maps", "vote", "remove", Int.parameter, use: gameMapController.voteForRemoval)
    router.post("maps", "vote", "promote", Int.parameter, use: gameMapController.voteForPromotion)

    /// Web part
    router.get("view", use:  gameMapViewController.index)
    router.get("view", "stats", use:  gameMapViewController.viewStats)
    router.get("view", "map", Int.parameter, use: gameMapViewController.viewMap)
    router.get("view", "maps", "random", use: gameMapViewController.viewRandomMap)
    router.get("view", "maps", "topseeds", use:  gameMapViewController.topSeeds)

    router.get("view", "maps", "seed", String.parameter, use: gameMapViewController.withSeed)
    router.get("view", "distribution", "seed", String.parameter, use: gameMapViewController.mapsDistribution)

}
