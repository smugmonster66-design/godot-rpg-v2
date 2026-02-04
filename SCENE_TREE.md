# Complete Scene Tree Documentation
Generated: 2026-01-30T09:33:26

## res://scenes/ui/menus/character_tab.tscn

```
├─ CharacterTab (Control)
   [Packed Scene: res://scenes/ui/menus/character_tab.tscn]
  ├─ HBoxContainer (HBoxContainer)
```

## res://scenes/ui/menus/equipment_tab.tscn

```
├─ EquipmentTab (Control)
   [Packed Scene: res://scenes/ui/menus/equipment_tab.tscn]
```

## res://scenes/ui/menus/inventory_tab.tscn

```
├─ InventoryTab (Control)
   [Packed Scene: res://scenes/ui/menus/inventory_tab.tscn]
```

## res://scenes/ui/menus/player_menu.tscn

```
├─ PlayerMenu (Control)
   [Packed Scene: res://scenes/ui/menus/player_menu.tscn]
  ├─ PanelContainer (Panel)
    ├─ VBoxContainer (VBoxContainer)
      ├─ TabContainer (TabContainer)
        ├─ Character (Control)
          ├─ VBoxContainer (VBoxContainer)
            ├─ ClassLabel (Label)
            ├─ LevelLabel (Label)
            ├─ HBoxContainer (HBoxContainer)
              ├─ ExpLabel (Label)
              ├─ Control (Control)
              ├─ ExpBar (ProgressBar)
            ├─ StatsContainer (VBoxContainer)
        ├─ Skills (Control)
           [Packed Scene: res://scenes/ui/menus/skills_tab.tscn]
          ├─ VBox (VBoxContainer)
            ├─ SkillPointsLabel (Label)
            ├─ ClassLabel (Label)
            ├─ TreeTabs (TabContainer)
            ├─ ResetButton (Button)
        ├─ Equipment (Control)
          ├─ VBoxContainer (VBoxContainer)
            ├─ Label (Label)
            ├─ EquipmentGrid (GridContainer)
              ├─ Control (Control)
              ├─ Head Slot (VBoxContainer)
                ├─ SlotButton (Button)
                ├─ Label (Label)
              ├─ Control2 (Control)
              ├─ MainHand Slot (VBoxContainer)
                ├─ SlotButton (Button)
                ├─ Label (Label)
              ├─ Torso Slot (VBoxContainer)
                ├─ SlotButton (Button)
                ├─ Label (Label)
              ├─ OffHand Slot (VBoxContainer)
                ├─ SlotButton (Button)
                ├─ Label (Label)
              ├─ Gloves Slot (VBoxContainer)
                ├─ SlotButton (Button)
                ├─ Label (Label)
              ├─ Boots Slot (VBoxContainer)
                ├─ SlotButton (Button)
                ├─ Label (Label)
              ├─ Accessory Slot (VBoxContainer)
                ├─ SlotButton (Button)
                ├─ Label (Label)
        ├─ Inventory (Control)
          ├─ VBoxContainer (VBoxContainer)
            ├─ CategoryTabs (TabContainer)
              ├─ All (Control)
              ├─ Head (Control)
              ├─ Torso (Control)
              ├─ Gloves (Control)
              ├─ Boots (Control)
              ├─ MainHand (Control)
              ├─ OffHand (Control)
              ├─ Accessory (Control)
              ├─ Consumable (Control)
            ├─ ScrollContainer (ScrollContainer)
              ├─ ItemGrid (GridContainer)
        ├─ Quests (Control)
      ├─ CloseButton (Button)
```

## res://scenes/ui/menus/skills_tab.tscn

```
├─ Skills (Control)
   [Packed Scene: res://scenes/ui/menus/skills_tab.tscn]
  ├─ VBox (VBoxContainer)
    ├─ SkillPointsLabel (Label)
    ├─ ClassLabel (Label)
    ├─ TreeTabs (TabContainer)
    ├─ ResetButton (Button)
```

## res://scenes/ui/combat/combatant_display.tscn

```
├─ CombatantDisplay (Control)
   [Packed Scene: res://scenes/ui/combat/combatant_display.tscn]
```

## res://scenes/ui/combat/player_menu.tscn

```
├─ PlayerMenu (Control)
   [Packed Scene: res://scenes/ui/combat/player_menu.tscn]
```

## res://scenes/ui/combat/dice_pool_display.tscn

```
├─ DicePoolDisplay (HBoxContainer)
   [Packed Scene: res://scenes/ui/combat/dice_pool_display.tscn]
```

## res://scenes/ui/combat/combat_scene.tscn

```
├─ CombatScene (Node2D)
   [Packed Scene: res://scenes/ui/combat/combat_scene.tscn]
  ├─ CombatUI (CanvasLayer)
    ├─ MarginContainer (MarginContainer)
      ├─ VBoxContainer (VBoxContainer)
        ├─ TopBar (HBoxContainer)
        ├─ CenterArea (Control)
        ├─ DicePoolDisplay (HBoxContainer)
        ├─ BottomBar (HBoxContainer)
  ├─ PlayerCombantant (Node2D)
     [Packed Scene: res://scenes/combatant.tscn]
    ├─ Sprite2D (Sprite2D)
    ├─ HealthLabel (Label)
  ├─ Enemy1 (Node2D)
     [Packed Scene: res://scenes/combatant.tscn]
    ├─ Sprite2D (Sprite2D)
    ├─ HealthLabel (Label)
  ├─ ActionFields (Container)
    ├─ ActionField (PanelContainer)
       [Packed Scene: res://scenes/ui/combat/action_field.tscn]
      ├─ VBoxContainer (VBoxContainer)
        ├─ NameLabel (Label)
        ├─ IconContainer (PanelContainer)
          ├─ CenterContainer (CenterContainer)
            ├─ VBoxContainer (VBoxContainer)
              ├─ IconRect (TextureRect)
              ├─ DieSlotsGrid (GridContainer)
                ├─ SlotPanel (PanelContainer)
                  ├─ EmptyLabel (Label)
        ├─ DescriptionLabel (RichTextLabel)
  ├─ ActionButtons (Container)
    ├─ VBoxContainer (VBoxContainer)
      ├─ HBoxContainer (HBoxContainer)
        ├─ ConfirmButton (Button)
        ├─ CancelButton (Button)
  ├─ EndTurnButton (Button)
```

## res://scenes/ui/combat/combat_ui.tscn

```
├─ CombatUILayer (CanvasLayer)
   [Packed Scene: res://scenes/ui/combat/combat_ui.tscn]
  ├─ MarginContainer (MarginContainer)
    ├─ VBox (VBoxContainer)
      ├─ TopBar (HBoxContainer)
        ├─ Control (Control)
        ├─ PlayerHealth (HBoxContainer)
          ├─ NameLabel (Label)
          ├─ Control (Control)
          ├─ ProgressBar (ProgressBar)
          ├─ ValueLabel (Label)
        ├─ EnemyHealth (HBoxContainer)
          ├─ NameLabel (Label)
          ├─ ProgressBar (ProgressBar)
          ├─ ValueLabel (Label)
        ├─ Control2 (Control)
      ├─ Spacer1 (Control)
      ├─ CenterArea (Control)
      ├─ ActionFieldsArea (VBoxContainer)
        ├─ CenterContainer (CenterContainer)
          ├─ ActionFieldsGrid (GridContainer)
            ├─ ActionField1 (PanelContainer)
            ├─ ActionField2 (PanelContainer)
            ├─ ActionField3 (PanelContainer)
            ├─ ActionField4 (PanelContainer)
            ├─ ActionField5 (PanelContainer)
            ├─ ActionField6 (PanelContainer)
            ├─ ActionField7 (PanelContainer)
            ├─ ActionField8 (PanelContainer)
            ├─ ActionField9 (PanelContainer)
            ├─ ActionField10 (PanelContainer)
            ├─ ActionField11 (PanelContainer)
            ├─ ActionField12 (PanelContainer)
            ├─ ActionField13 (PanelContainer)
            ├─ ActionField14 (PanelContainer)
            ├─ ActionField15 (PanelContainer)
            ├─ ActionField16 (PanelContainer)
      ├─ Spacer2 (Control)
      ├─ ActionAreaContainer (VBoxContainer)
        ├─ CategoryNavigation (HBoxContainer)
          ├─ LeftButton (Button)
          ├─ CategoryLabel (Label)
          ├─ RightButton (Button)
        ├─ ActionFieldsScroller (Control)
          ├─ ItemsColumn (ScrollContainer)
            ├─ ItemsGrid (GridContainer)
          ├─ SkillsColumn (ScrollContainer)
            ├─ SkillsGrid (GridContainer)
      ├─ Spacer3 (Control)
      ├─ DicePoolArea (CenterContainer)
        ├─ DicePoolDisplay (HBoxContainer)
           [Packed Scene: res://scenes/ui/combat/dice_pool_display.tscn]
        ├─ DicePoolLabel (Label)
      ├─ ButtonArea (CenterContainer)
        ├─ VBoxContainer (VBoxContainer)
          ├─ ActionButtonsContainer (HBoxContainer)
            ├─ ConfirmButton (Button)
            ├─ CancelButton (Button)
          ├─ Spacer4 (Control)
          ├─ EndTurnButton (Button)
```

## res://scenes/ui/combat/action_field.tscn

```
├─ ActionField (PanelContainer)
   [Packed Scene: res://scenes/ui/combat/action_field.tscn]
  ├─ VBoxContainer (VBoxContainer)
    ├─ NameLabel (Label)
    ├─ IconContainer (PanelContainer)
      ├─ CenterContainer (CenterContainer)
        ├─ VBoxContainer (VBoxContainer)
          ├─ IconRect (TextureRect)
          ├─ DieSlotsGrid (GridContainer)
            ├─ SlotPanel (PanelContainer)
              ├─ EmptyLabel (Label)
    ├─ DescriptionLabel (RichTextLabel)
```

## res://scenes/ui/components/icon_button.tscn

```
├─ IconButton (Control)
   [Packed Scene: res://scenes/ui/components/icon_button.tscn]
  ├─ Background (Panel)
  ├─ Icon (TextureRect)
  ├─ Label (Label)
```

## res://scenes/ui/components/item_card.tscn

```
├─ ItemCard (PanelContainer)
   [Packed Scene: res://scenes/ui/components/item_card.tscn]
```

## res://scenes/ui/components/stat_display.tscn

```
├─ StatDisplay (HBoxContainer)
   [Packed Scene: res://scenes/ui/components/stat_display.tscn]
```

## res://scenes/ui/components/die_visual.tscn

```
├─ DieVisual (PanelContainer)
   [Packed Scene: res://scenes/ui/components/die_visual.tscn]
  ├─ VBoxContainer (VBoxContainer)
    ├─ TypeLabel (Label)
    ├─ ValueLabel (Label)
    ├─ TagsLabel (Label)
```

## res://scenes/ui/components/skill_button.tscn

```
├─ SkillButton (PanelContainer)
   [Packed Scene: res://scenes/ui/components/skill_button.tscn]
  ├─ VBox (VBoxContainer)
    ├─ NameLabel (Label)
    ├─ RankLabel (Label)
    ├─ DescLabel (Label)
    ├─ LearnButton (Button)
    ├─ RequirementsLabel (RichTextLabel)
```

## res://scenes/ui/popups/post_combat_summary.tscn

```
├─ PostCombatSummary (Control)
   [Packed Scene: res://scenes/ui/popups/post_combat_summary.tscn]
```

## res://scenes/ui/popups/location_popup.tscn

```
├─ LocationPopup (Control)
   [Packed Scene: res://scenes/ui/popups/location_popup.tscn]
```

## res://scenes/controltest.tscn

```
├─ Control (Control)
   [Packed Scene: res://scenes/controltest.tscn]
  ├─ TextureButton (TextureButton)
```

## res://scenes/game/map_scene.tscn

```
├─ MapScene (Node2D)
   [Packed Scene: res://scenes/game/map_scene.tscn]
  ├─ MapNodesContainer (Node2D)
    ├─ TownNode (Node2D)
      ├─ Sprite2D (Sprite2D)
      ├─ Area2D (Area2D)
        ├─ CollisionShape2D (CollisionShape2D)
    ├─ ForestNode (Node2D)
      ├─ Sprite2D (Sprite2D)
      ├─ Area2D (Area2D)
        ├─ CollisionShape2D (CollisionShape2D)
    ├─ DungeonNode (Node2D)
      ├─ Sprite2D (Sprite2D)
      ├─ Area2D (Area2D)
        ├─ CollisionShape2D (CollisionShape2D)
  ├─ PathLines (Node2D)
  ├─ PlayerIcon (Node2D)
  ├─ UILayer (CanvasLayer)
    ├─ TopBar (HBoxContainer)
      ├─ MenuButton (Button)
      ├─ CombatButton (Button)
    ├─ PlayerMenu (Control)
       [Packed Scene: res://scenes/ui/menus/player_menu.tscn]
      ├─ PanelContainer (Panel)
        ├─ VBoxContainer (VBoxContainer)
          ├─ TabContainer (TabContainer)
            ├─ Character (Control)
              ├─ VBoxContainer (VBoxContainer)
                ├─ ClassLabel (Label)
                ├─ LevelLabel (Label)
                ├─ HBoxContainer (HBoxContainer)
                  ├─ ExpLabel (Label)
                  ├─ Control (Control)
                  ├─ ExpBar (ProgressBar)
                ├─ StatsContainer (VBoxContainer)
            ├─ Skills (Control)
               [Packed Scene: res://scenes/ui/menus/skills_tab.tscn]
              ├─ VBox (VBoxContainer)
                ├─ SkillPointsLabel (Label)
                ├─ ClassLabel (Label)
                ├─ TreeTabs (TabContainer)
                ├─ ResetButton (Button)
            ├─ Equipment (Control)
              ├─ VBoxContainer (VBoxContainer)
                ├─ Label (Label)
                ├─ EquipmentGrid (GridContainer)
                  ├─ Control (Control)
                  ├─ Head Slot (VBoxContainer)
                    ├─ SlotButton (Button)
                    ├─ Label (Label)
                  ├─ Control2 (Control)
                  ├─ MainHand Slot (VBoxContainer)
                    ├─ SlotButton (Button)
                    ├─ Label (Label)
                  ├─ Torso Slot (VBoxContainer)
                    ├─ SlotButton (Button)
                    ├─ Label (Label)
                  ├─ OffHand Slot (VBoxContainer)
                    ├─ SlotButton (Button)
                    ├─ Label (Label)
                  ├─ Gloves Slot (VBoxContainer)
                    ├─ SlotButton (Button)
                    ├─ Label (Label)
                  ├─ Boots Slot (VBoxContainer)
                    ├─ SlotButton (Button)
                    ├─ Label (Label)
                  ├─ Accessory Slot (VBoxContainer)
                    ├─ SlotButton (Button)
                    ├─ Label (Label)
            ├─ Inventory (Control)
              ├─ VBoxContainer (VBoxContainer)
                ├─ CategoryTabs (TabContainer)
                  ├─ All (Control)
                  ├─ Head (Control)
                  ├─ Torso (Control)
                  ├─ Gloves (Control)
                  ├─ Boots (Control)
                  ├─ MainHand (Control)
                  ├─ OffHand (Control)
                  ├─ Accessory (Control)
                  ├─ Consumable (Control)
                ├─ ScrollContainer (ScrollContainer)
                  ├─ ItemGrid (GridContainer)
            ├─ Quests (Control)
          ├─ CloseButton (Button)
    ├─ PostCombatSummary (Control)
      ├─ ColorRect (ColorRect)
      ├─ CenterContainer (CenterContainer)
        ├─ PanelContainer (PanelContainer)
          ├─ VBoxContainer (VBoxContainer)
            ├─ TitleLabel (Label)
            ├─ HSeparator (HSeparator)
            ├─ ExpSection (VBoxContainer)
              ├─ ExpLabel (Label)
              ├─ ExpValue (Label)
            ├─ HSeparator2 (HSeparator)
            ├─ LootSection (VBoxContainer)
              ├─ LootLabel (Label)
              ├─ LootGrid (GridContainer)
            ├─ HSeparator3 (HSeparator)
            ├─ CloseButton (Button)
```

## res://scenes/game/game_root.tscn

```
├─ GameRoot (Node)
   [Packed Scene: res://scenes/game/game_root.tscn]
  ├─ MapScene (Node2D)
     [Packed Scene: res://scenes/game/map_scene.tscn]
    ├─ MapNodesContainer (Node2D)
      ├─ TownNode (Node2D)
        ├─ Sprite2D (Sprite2D)
        ├─ Area2D (Area2D)
          ├─ CollisionShape2D (CollisionShape2D)
      ├─ ForestNode (Node2D)
        ├─ Sprite2D (Sprite2D)
        ├─ Area2D (Area2D)
          ├─ CollisionShape2D (CollisionShape2D)
      ├─ DungeonNode (Node2D)
        ├─ Sprite2D (Sprite2D)
        ├─ Area2D (Area2D)
          ├─ CollisionShape2D (CollisionShape2D)
    ├─ PathLines (Node2D)
    ├─ PlayerIcon (Node2D)
    ├─ UILayer (CanvasLayer)
      ├─ TopBar (HBoxContainer)
        ├─ MenuButton (Button)
        ├─ CombatButton (Button)
      ├─ PlayerMenu (Control)
         [Packed Scene: res://scenes/ui/menus/player_menu.tscn]
        ├─ PanelContainer (Panel)
          ├─ VBoxContainer (VBoxContainer)
            ├─ TabContainer (TabContainer)
              ├─ Character (Control)
                ├─ VBoxContainer (VBoxContainer)
                  ├─ ClassLabel (Label)
                  ├─ LevelLabel (Label)
                  ├─ HBoxContainer (HBoxContainer)
                    ├─ ExpLabel (Label)
                    ├─ Control (Control)
                    ├─ ExpBar (ProgressBar)
                  ├─ StatsContainer (VBoxContainer)
              ├─ Skills (Control)
                 [Packed Scene: res://scenes/ui/menus/skills_tab.tscn]
                ├─ VBox (VBoxContainer)
                  ├─ SkillPointsLabel (Label)
                  ├─ ClassLabel (Label)
                  ├─ TreeTabs (TabContainer)
                  ├─ ResetButton (Button)
              ├─ Equipment (Control)
                ├─ VBoxContainer (VBoxContainer)
                  ├─ Label (Label)
                  ├─ EquipmentGrid (GridContainer)
                    ├─ Control (Control)
                    ├─ Head Slot (VBoxContainer)
                      ├─ SlotButton (Button)
                      ├─ Label (Label)
                    ├─ Control2 (Control)
                    ├─ MainHand Slot (VBoxContainer)
                      ├─ SlotButton (Button)
                      ├─ Label (Label)
                    ├─ Torso Slot (VBoxContainer)
                      ├─ SlotButton (Button)
                      ├─ Label (Label)
                    ├─ OffHand Slot (VBoxContainer)
                      ├─ SlotButton (Button)
                      ├─ Label (Label)
                    ├─ Gloves Slot (VBoxContainer)
                      ├─ SlotButton (Button)
                      ├─ Label (Label)
                    ├─ Boots Slot (VBoxContainer)
                      ├─ SlotButton (Button)
                      ├─ Label (Label)
                    ├─ Accessory Slot (VBoxContainer)
                      ├─ SlotButton (Button)
                      ├─ Label (Label)
              ├─ Inventory (Control)
                ├─ VBoxContainer (VBoxContainer)
                  ├─ CategoryTabs (TabContainer)
                    ├─ All (Control)
                    ├─ Head (Control)
                    ├─ Torso (Control)
                    ├─ Gloves (Control)
                    ├─ Boots (Control)
                    ├─ MainHand (Control)
                    ├─ OffHand (Control)
                    ├─ Accessory (Control)
                    ├─ Consumable (Control)
                  ├─ ScrollContainer (ScrollContainer)
                    ├─ ItemGrid (GridContainer)
              ├─ Quests (Control)
            ├─ CloseButton (Button)
      ├─ PostCombatSummary (Control)
        ├─ ColorRect (ColorRect)
        ├─ CenterContainer (CenterContainer)
          ├─ PanelContainer (PanelContainer)
            ├─ VBoxContainer (VBoxContainer)
              ├─ TitleLabel (Label)
              ├─ HSeparator (HSeparator)
              ├─ ExpSection (VBoxContainer)
                ├─ ExpLabel (Label)
                ├─ ExpValue (Label)
              ├─ HSeparator2 (HSeparator)
              ├─ LootSection (VBoxContainer)
                ├─ LootLabel (Label)
                ├─ LootGrid (GridContainer)
              ├─ HSeparator3 (HSeparator)
              ├─ CloseButton (Button)
  ├─ CombatScene (Node2D)
     [Packed Scene: res://scenes/game/combat_scene.tscn]
    ├─ EnemyCombatant (Node2D)
       [Packed Scene: res://scenes/entities/enemy_combatant.tscn]
      ├─ Sprite2D (Sprite2D)
      ├─ HealthLabel (Label)
    ├─ PlayerCombatant (Node2D)
       [Packed Scene: res://scenes/entities/player_combatant.tscn]
      ├─ Sprite2D (Sprite2D)
      ├─ HealthLabel (Label)
    ├─ CombatUILayer (CanvasLayer)
       [Packed Scene: res://scenes/ui/combat/combat_ui.tscn]
      ├─ MarginContainer (MarginContainer)
        ├─ VBox (VBoxContainer)
          ├─ TopBar (HBoxContainer)
            ├─ Control (Control)
            ├─ PlayerHealth (HBoxContainer)
              ├─ NameLabel (Label)
              ├─ Control (Control)
              ├─ ProgressBar (ProgressBar)
              ├─ ValueLabel (Label)
            ├─ EnemyHealth (HBoxContainer)
              ├─ NameLabel (Label)
              ├─ ProgressBar (ProgressBar)
              ├─ ValueLabel (Label)
            ├─ Control2 (Control)
          ├─ Spacer1 (Control)
          ├─ CenterArea (Control)
          ├─ ActionFieldsArea (VBoxContainer)
            ├─ CenterContainer (CenterContainer)
              ├─ ActionFieldsGrid (GridContainer)
                ├─ ActionField1 (PanelContainer)
                ├─ ActionField2 (PanelContainer)
                ├─ ActionField3 (PanelContainer)
                ├─ ActionField4 (PanelContainer)
                ├─ ActionField5 (PanelContainer)
                ├─ ActionField6 (PanelContainer)
                ├─ ActionField7 (PanelContainer)
                ├─ ActionField8 (PanelContainer)
                ├─ ActionField9 (PanelContainer)
                ├─ ActionField10 (PanelContainer)
                ├─ ActionField11 (PanelContainer)
                ├─ ActionField12 (PanelContainer)
                ├─ ActionField13 (PanelContainer)
                ├─ ActionField14 (PanelContainer)
                ├─ ActionField15 (PanelContainer)
                ├─ ActionField16 (PanelContainer)
          ├─ Spacer2 (Control)
          ├─ ActionAreaContainer (VBoxContainer)
            ├─ CategoryNavigation (HBoxContainer)
              ├─ LeftButton (Button)
              ├─ CategoryLabel (Label)
              ├─ RightButton (Button)
            ├─ ActionFieldsScroller (Control)
              ├─ ItemsColumn (ScrollContainer)
                ├─ ItemsGrid (GridContainer)
              ├─ SkillsColumn (ScrollContainer)
                ├─ SkillsGrid (GridContainer)
          ├─ Spacer3 (Control)
          ├─ DicePoolArea (CenterContainer)
            ├─ DicePoolDisplay (HBoxContainer)
               [Packed Scene: res://scenes/ui/combat/dice_pool_display.tscn]
            ├─ DicePoolLabel (Label)
          ├─ ButtonArea (CenterContainer)
            ├─ VBoxContainer (VBoxContainer)
              ├─ ActionButtonsContainer (HBoxContainer)
                ├─ ConfirmButton (Button)
                ├─ CancelButton (Button)
              ├─ Spacer4 (Control)
              ├─ EndTurnButton (Button)
```

## res://scenes/game/combat_scene.tscn

```
├─ CombatScene (Node2D)
   [Packed Scene: res://scenes/game/combat_scene.tscn]
  ├─ EnemyCombatant (Node2D)
     [Packed Scene: res://scenes/entities/enemy_combatant.tscn]
    ├─ Sprite2D (Sprite2D)
    ├─ HealthLabel (Label)
  ├─ PlayerCombatant (Node2D)
     [Packed Scene: res://scenes/entities/player_combatant.tscn]
    ├─ Sprite2D (Sprite2D)
    ├─ HealthLabel (Label)
  ├─ CombatUILayer (CanvasLayer)
     [Packed Scene: res://scenes/ui/combat/combat_ui.tscn]
    ├─ MarginContainer (MarginContainer)
      ├─ VBox (VBoxContainer)
        ├─ TopBar (HBoxContainer)
          ├─ Control (Control)
          ├─ PlayerHealth (HBoxContainer)
            ├─ NameLabel (Label)
            ├─ Control (Control)
            ├─ ProgressBar (ProgressBar)
            ├─ ValueLabel (Label)
          ├─ EnemyHealth (HBoxContainer)
            ├─ NameLabel (Label)
            ├─ ProgressBar (ProgressBar)
            ├─ ValueLabel (Label)
          ├─ Control2 (Control)
        ├─ Spacer1 (Control)
        ├─ CenterArea (Control)
        ├─ ActionFieldsArea (VBoxContainer)
          ├─ CenterContainer (CenterContainer)
            ├─ ActionFieldsGrid (GridContainer)
              ├─ ActionField1 (PanelContainer)
              ├─ ActionField2 (PanelContainer)
              ├─ ActionField3 (PanelContainer)
              ├─ ActionField4 (PanelContainer)
              ├─ ActionField5 (PanelContainer)
              ├─ ActionField6 (PanelContainer)
              ├─ ActionField7 (PanelContainer)
              ├─ ActionField8 (PanelContainer)
              ├─ ActionField9 (PanelContainer)
              ├─ ActionField10 (PanelContainer)
              ├─ ActionField11 (PanelContainer)
              ├─ ActionField12 (PanelContainer)
              ├─ ActionField13 (PanelContainer)
              ├─ ActionField14 (PanelContainer)
              ├─ ActionField15 (PanelContainer)
              ├─ ActionField16 (PanelContainer)
        ├─ Spacer2 (Control)
        ├─ ActionAreaContainer (VBoxContainer)
          ├─ CategoryNavigation (HBoxContainer)
            ├─ LeftButton (Button)
            ├─ CategoryLabel (Label)
            ├─ RightButton (Button)
          ├─ ActionFieldsScroller (Control)
            ├─ ItemsColumn (ScrollContainer)
              ├─ ItemsGrid (GridContainer)
            ├─ SkillsColumn (ScrollContainer)
              ├─ SkillsGrid (GridContainer)
        ├─ Spacer3 (Control)
        ├─ DicePoolArea (CenterContainer)
          ├─ DicePoolDisplay (HBoxContainer)
             [Packed Scene: res://scenes/ui/combat/dice_pool_display.tscn]
          ├─ DicePoolLabel (Label)
        ├─ ButtonArea (CenterContainer)
          ├─ VBoxContainer (VBoxContainer)
            ├─ ActionButtonsContainer (HBoxContainer)
              ├─ ConfirmButton (Button)
              ├─ CancelButton (Button)
            ├─ Spacer4 (Control)
            ├─ EndTurnButton (Button)
```

## res://scenes/entities/enemy_combatant.tscn

```
├─ EnemyCombatant (Node2D)
   [Packed Scene: res://scenes/entities/enemy_combatant.tscn]
  ├─ Sprite2D (Sprite2D)
  ├─ HealthLabel (Label)
```

## res://scenes/entities/player_combatant.tscn

```
├─ PlayerCombatant (Node2D)
   [Packed Scene: res://scenes/entities/player_combatant.tscn]
  ├─ Sprite2D (Sprite2D)
  ├─ HealthLabel (Label)
```

## res://scenes/menu_test.tscn

```
├─ MenuTest (Control)
   [Packed Scene: res://scenes/menu_test.tscn]
  ├─ PlayerMenuMobile (Control)
```

## res://scenes/combatant.tscn

```
├─ Combatant (Node2D)
   [Packed Scene: res://scenes/combatant.tscn]
  ├─ Sprite2D (Sprite2D)
  ├─ HealthLabel (Label)
```

## res://scenes/player.tscn

```
├─ Player (Node2D)
   [Packed Scene: res://scenes/player.tscn]
```

## res://scenes/game.tscn

```
├─ Game (Node2D)
   [Packed Scene: res://scenes/game.tscn]
```

## res://scenes/game_manager.tscn

```
├─ GameManager (Node2D)
   [Packed Scene: res://scenes/game_manager.tscn]
```

## res://scenes/Root.tscn

```
├─ GameRoot (Node2D)
   [Packed Scene: res://scenes/Root.tscn]
  ├─ CombatScene (Node2D)
     [Packed Scene: res://scenes/ui/combat/combat_scene.tscn]
    ├─ CombatUI (CanvasLayer)
      ├─ MarginContainer (MarginContainer)
        ├─ VBoxContainer (VBoxContainer)
          ├─ TopBar (HBoxContainer)
          ├─ CenterArea (Control)
          ├─ DicePoolDisplay (HBoxContainer)
          ├─ BottomBar (HBoxContainer)
    ├─ PlayerCombantant (Node2D)
       [Packed Scene: res://scenes/combatant.tscn]
      ├─ Sprite2D (Sprite2D)
      ├─ HealthLabel (Label)
    ├─ Enemy1 (Node2D)
       [Packed Scene: res://scenes/combatant.tscn]
      ├─ Sprite2D (Sprite2D)
      ├─ HealthLabel (Label)
    ├─ ActionFields (Container)
      ├─ ActionField (PanelContainer)
         [Packed Scene: res://scenes/ui/combat/action_field.tscn]
        ├─ VBoxContainer (VBoxContainer)
          ├─ NameLabel (Label)
          ├─ IconContainer (PanelContainer)
            ├─ CenterContainer (CenterContainer)
              ├─ VBoxContainer (VBoxContainer)
                ├─ IconRect (TextureRect)
                ├─ DieSlotsGrid (GridContainer)
                  ├─ SlotPanel (PanelContainer)
                    ├─ EmptyLabel (Label)
          ├─ DescriptionLabel (RichTextLabel)
    ├─ ActionButtons (Container)
      ├─ VBoxContainer (VBoxContainer)
        ├─ HBoxContainer (HBoxContainer)
          ├─ ConfirmButton (Button)
          ├─ CancelButton (Button)
    ├─ EndTurnButton (Button)
```

## res://scenes/die.tscn

```
├─ Die (Control)
   [Packed Scene: res://scenes/die.tscn]
  ├─ Panel (Panel)
  ├─ ValueLabel (Label)
```

## res://scenes/map_scene.tscn

```
├─ MapScene (Node2D)
   [Packed Scene: res://scenes/map_scene.tscn]
  ├─ Town (Node2D)
  ├─ Forest (Node2D)
  ├─ Mountain (Node2D)
  ├─ UILayer (CanvasLayer)
    ├─ CombatButton (Button)
    ├─ MenuButton (Button)
    ├─ PlayerMenuMobile (MissingNode)
```

## res://scenes/skill_tree_panel.tscn

```
├─ SkillTreePanel (Control)
   [Packed Scene: res://scenes/skill_tree_panel.tscn]
  ├─ VBox (VBoxContainer)
    ├─ TreeNameLabel (Label)
    ├─ TreeDescLabel (Label)
    ├─ ScrollContainer (ScrollContainer)
      ├─ SkillGrid (VBoxContainer)
```

