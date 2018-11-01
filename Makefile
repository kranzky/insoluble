# vim: noexpandtab filetype=make

TARGET = insoluble

DEPDIR := .d
DEPFLAGS = -MT $@ -MMD -MP -MF $(DEPDIR)/$*.Td

CC = gcc
CFLAGS = -g -std=c11 -pedantic-errors -Wall $(DEPFLAGS)

LINKER = gcc -o
LFLAGS = -g -Wall

SRCDIR = src
OBJDIR = obj
BINDIR = bin

SOURCES := $(wildcard $(SRCDIR)/*.c)
INCLUDES := $(wildcard $(SRCDIR)/*.h)
OBJECTS := $(SOURCES:$(SRCDIR)/%.c=$(OBJDIR)/%.o)
rm = rm -f

POSTCOMPILE = @mv -f $(DEPDIR)/$*.Td $(DEPDIR)/$*.d && touch $@

$(shell mkdir -p $(DEPDIR) >/dev/null)

$(BINDIR)/$(TARGET): $(OBJECTS)
	$(LINKER) $@ $(LFLAGS) $(OBJECTS)

$(OBJDIR)/%.o : $(SRCDIR)/%.c
$(OBJDIR)/%.o : $(SRCDIR)/%.c $(DEPDIR)/%.d
	$(CC) $(CFLAGS) -c $< -o $@
	$(POSTCOMPILE)

$(DEPDIR)/%.d: ;
.PRECIOUS: $(DEPDIR)/%.d

.PHONEY: clean
clean:
	$(rm) $(wildcard $(DEPDIR)/*.d)
	$(rm) $(OBJECTS)
	$(rm) $(BINDIR)/$(TARGET)

include $(wildcard $(DEPDIR)/*.d)
