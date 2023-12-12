import SpriteKit

// MARK: - Scene

public extension SKScene {
    static func load<T>(_ type: T.Type, filename: String, inBundleForClass bundleClass: AnyClass) -> T? where T: SKScene {
        load(type, filename: filename, in: .init(for: bundleClass))
    }
    
    static func load<T>(_ type: T.Type, filename: String, in bundle: Bundle) -> T? where T: SKScene {
        guard let path = bundle.path(forResource: filename, ofType: "sks") else { return nil }
        guard let data = FileManager.default.contents(atPath: path) else { return nil }
        
        guard let object = NSKeyedUnarchiver.unarchiveObject(with: data) else { return nil }
        return object as? T
    }
}

// MARK: - Texture

public extension SKTexture {
    static func imageNamed(_ name: String, inBundleForClass bundleClass: AnyClass) -> SKTexture? {
        imageNamed(name, in: .init(for: bundleClass))
    }
    
    static func imageNamed(_ name: String, in bundle: Bundle) -> SKTexture? {
        guard let image = UIImage(named: name, in: bundle, compatibleWith: nil) else {
            return nil
        }
        
        return .init(image: image)
    }
}

// MARK: - Sound

public extension SKAudioNode {
    static func soundNamed(_ name: String, inBundleForClass bundleClass: AnyClass) -> SKAudioNode? {
        soundNamed(name, in: .init(for: bundleClass))
    }
    
    static func soundNamed(_ name: String, in bundle: Bundle) -> SKAudioNode? {
        let nameParts = name.split(separator: ".")
        guard nameParts.count == 2 else { return nil }
        guard let url = bundle.url(forResource: String(nameParts[0]), withExtension: String(nameParts[1])) else { return nil }
        
        return SKAudioNode(url: url)
    }
}
