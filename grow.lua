local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

local Window = Rayfield:CreateWindow({
    Name = "Contoh UI Sederhana",
    LoadingTitle = "Memuat...",
    LoadingSubtitle = "by Kamu",
    ConfigurationSaving = {
        Enabled = false
    },
    KeySystem = false
})

local Tab1 = Window:CreateTab("Tab Utama", 4483362458) -- ID icon (opsional)

Tab1:CreateSection("Pengaturan")

Tab1:CreateButton({
    Name = "Tombol Contoh",
    Callback = function()
        print("Tombol ditekan!")
    end,
})

Tab1:CreateToggle({
    Name = "Toggle Contoh",
    CurrentValue = false,
    Callback = function(Value)
        print("Toggle: " .. tostring(Value))
    end,
})

Tab1:CreateSlider({
    Name = "Slider Contoh",
    Range = {0, 100},
    Increment = 1,
    CurrentValue = 50,
    Callback = function(Value)
        print("Slider: " .. tostring(Value))
    end,
})

Tab1:CreateDropdown({
    Name = "Dropdown Contoh",
    Options = {"Opsi 1", "Opsi 2", "Opsi 3"},
    CurrentOption = "Opsi 1",
    Callback = function(Option)
        print("Dipilih: " .. tostring(Option))
    end,
})

Tab1:CreateLabel("Ini contoh label teks.")
