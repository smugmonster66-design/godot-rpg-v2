# section_header.gd - Styled section title label
extends Label

func set_title(text: String):
	self.text = text
	theme_type_variation = "charmenuheader"
