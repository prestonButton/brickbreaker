import UIKit

// MARK: - Delegate

public protocol GamePauseDelegate: AnyObject {
    func musicStatusChanged(isOn: Bool)
    func sfxStatusChanged(isOn: Bool)
    func hapticsStatusChanged(isOn: Bool)
    func rulesTapped()
    func continueTapped()
    func forfeitTapped()
    
    func isMusicPreferred() -> Bool
    func isSFXPreferred() -> Bool
    func areHapticsPreferred() -> Bool?
}

// MARK: - View

open class GamePauseView: UIView {
    
    public weak var delegate: GamePauseDelegate? {
        didSet {
            pauseSheet.delegate = delegate
        }
    }
    
    public weak var gameDelegate: GameDelegate? {
        didSet {
            pauseSheet.gameDelegate = gameDelegate
        }
    }
    
    lazy var pauseSheet: GamePauseSheet = {
        let pauseSheet = GamePauseSheet()
        pauseSheet.translatesAutoresizingMaskIntoConstraints = false
        return pauseSheet
    }()
    
    public override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
        setupConstraints()
    }
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func setupView() {
        backgroundColor = .black.withAlphaComponent(0.8)
        addSubview(pauseSheet)
    }
    
    func setupConstraints() {
        NSLayoutConstraint.activate([
            pauseSheet.centerXAnchor.constraint(equalTo: centerXAnchor),
            pauseSheet.centerYAnchor.constraint(equalTo: centerYAnchor),
            pauseSheet.widthAnchor.constraint(equalToConstant: 349)
        ])
    }
    
    public func updateView() {
        pauseSheet.updateView()
    }
}

// MARK: - Sheet

class GamePauseSheet: UIView {
    
    weak var delegate: GamePauseDelegate?
    weak var gameDelegate: GameDelegate? {
        didSet {
            for onSet in onGameDelegateDidSet {
                onSet(gameDelegate)
            }
        }
    }
    
    private var onGameDelegateDidSet: [(GameDelegate?) -> Void] = []
    
    // MARK: - Stacks
    lazy var stackView: UIStackView = {
        let stack = UIStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.distribution = .fill
        stack.axis = .vertical
        stack.spacing = 28
        
        stack.addArrangedSubview(titleStack)
        stack.addArrangedSubview(configStack)
        stack.addArrangedSubview(buttonStack)
        return stack
    }()
    
    lazy var titleStack: UIStackView = {
        let stack = UIStackView()
        stack.spacing = 4
        stack.axis = .vertical
        stack.distribution = .fill
        
        stack.addArrangedSubview(titleLabel)
        stack.addArrangedSubview(subtitleLabel)
        
        return stack
    }()
    
    lazy var configStack: UIStackView = {
        let stack = UIStackView()
        stack.spacing = 12
        stack.distribution = .fill
        stack.axis = .vertical
        return stack
    }()
    
    lazy var buttonStack: UIStackView = {
        let stack = UIStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.distribution = .fill
        stack.axis = .vertical
        stack.spacing = 12
        
        stack.addArrangedSubview(createButton(title: "Rules", style: .secondary))
        stack.addArrangedSubview(createButton(title: "Continue", style: .primary))
        stack.addArrangedSubview(createButton(title: "Forfeit Game", style: .tertiary))
        return stack
    }()
    
    // MARK: - Views
    lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.text = "Game Paused"
        label.font = .systemFont(ofSize: 36, weight: .semibold)
        label.textAlignment = .center
        label.textColor = .white
        label.adjustsFontSizeToFitWidth = true
        return label
    }()
    
    lazy var subtitleLabel: UILabel = {
        let label = UILabel()
        label.text = "90 minutes to submit score\nsince start"
        label.font = .systemFont(ofSize: 20, weight: .regular)
        label.textAlignment = .center
        label.textColor = .tungsten
        label.adjustsFontSizeToFitWidth = true
        label.numberOfLines = 2
        return label
    }()
    
    // MARK: View factories
    func createToggleStack(title: String, tag: Int, isOn: Bool) -> UIStackView {
        let stack = UIStackView()
        stack.distribution = .fill
        stack.axis = .horizontal
        
        // Title Label
        let label = UILabel()
        label.text = title
        label.textAlignment = .left
        label.font = .systemFont(ofSize: 20, weight: .regular)
        label.textColor = .white
        
        // Toggle
        let toggle = UISwitch()
        toggle.tag = tag
        toggle.onTintColor = gameDelegate?.primaryColor
        onGameDelegateDidSet.append { [weak toggle] in
            toggle?.onTintColor = $0?.primaryColor
        }
        toggle.addTarget(self, action: #selector(toggleSwitched(_:)), for: .valueChanged)
        toggle.isOn = isOn
        
        stack.addArrangedSubview(label)
        stack.addArrangedSubview(toggle)
        
        return stack
    }
    
    func createButton(title: String, style: ButtonStyle) -> UIButton {
        let button = UIButton()
        button.tag = style.rawValue
        button.addTarget(self, action: #selector(buttonPressed(_:)), for: .touchUpInside)
        switch style {
        case .primary, .secondary:
            button.backgroundColor = style == .primary ? gameDelegate?.primaryColor : .ironDark
            onGameDelegateDidSet.append { [weak button] in
                button?.backgroundColor = style == .primary ? $0?.primaryColor : .ironDark
            }
            button.setTitle(title, for: .normal)
            button.setTitleColor(.white, for: .normal)
            button.titleLabel?.font = .systemFont(ofSize: 20, weight: .regular)
            button.layer.cornerRadius = 25
            button.heightAnchor.constraint(equalToConstant: 50).isActive = true
        case .tertiary:
            let attrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 15, weight: .regular),
                .foregroundColor: UIColor.white,
                .underlineStyle: NSUnderlineStyle.single.rawValue
            ]
            button.backgroundColor = .clear
            button.setAttributedTitle(NSAttributedString(string: title, attributes: attrs), for: .normal)
        }
        
        return button
    }
    
    // MARK: - Types
    enum Toggle: Int {
        case music = 0
        case sfx = 1
        case haptics = 2
    }
    
    enum ButtonStyle: Int {
        case primary = 0
        case secondary = 1
        case tertiary = 2
    }
    
    // MARK: - Interaction Handling
    @objc func toggleSwitched(_ sender: Any) {
        guard let toggle = sender as? UISwitch else { return }
        guard let toggleType = Toggle(rawValue: toggle.tag) else { return }
        
        switch toggleType {
        case .music:
            delegate?.musicStatusChanged(isOn: toggle.isOn)
        case .sfx:
            delegate?.sfxStatusChanged(isOn: toggle.isOn)
        case .haptics:
            delegate?.hapticsStatusChanged(isOn: toggle.isOn)
        }
    }
    
    @objc func buttonPressed(_ sender: Any) {
        guard let button = sender as? UIButton else { return }
        guard let style = ButtonStyle(rawValue: button.tag) else { return }
        UIImpactFeedbackGenerator().impactOccurred()
        switch style {
        case .primary:
            delegate?.continueTapped()
        case .secondary:
            delegate?.rulesTapped()
        case .tertiary:
            delegate?.forfeitTapped()
        }
    }
    
    // MARK: - View Setup
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
        setupConstraints()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func setupView() {
        backgroundColor = .black
        layer.cornerRadius = 30
        layer.masksToBounds = false
        layer.shadowOffset = .zero
        layer.shadowRadius = 4
        layer.shadowOpacity = 0.1
        layer.shadowColor = UIColor.white.cgColor
        layer.borderWidth = 2
        layer.borderColor = gameDelegate?.primaryColor.cgColor
        onGameDelegateDidSet.append { [weak self] in
            self?.layer.borderColor = $0?.primaryColor.cgColor
        }
        addSubview(stackView)
    }
    
    func setupConstraints() {
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: topAnchor, constant: 28),
            stackView.leftAnchor.constraint(equalTo: leftAnchor, constant: 16),
            stackView.rightAnchor.constraint(equalTo: rightAnchor, constant: -16),
            stackView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -12)
        ])
    }
    
    func updateView() {
        for subview in configStack.arrangedSubviews {
            subview.removeFromSuperview()
        }
        
        configStack.addArrangedSubview(createToggleStack(title: "Music", tag: 0, isOn: delegate?.isMusicPreferred() ?? true))
        configStack.addArrangedSubview(createToggleStack(title: "SFX", tag: 1, isOn: delegate?.isSFXPreferred() ?? true))
        configStack.addArrangedSubview(createToggleStack(title: "Haptics", tag: 2, isOn: delegate?.areHapticsPreferred() ?? true))
    }
}


extension UIColor {
    static let tungsten = #colorLiteral(red: 0.2039215686, green: 0.2196078431, blue: 0.2470588235, alpha: 1)
    static let ironDark = #colorLiteral(red: 0.1261, green: 0.1261, blue: 0.13, alpha: 1)
}
