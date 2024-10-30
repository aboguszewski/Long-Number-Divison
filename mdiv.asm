global mdiv
section .text

mdiv:
; Argumenty:
; rdi - adres dzielnej (x)
; rsi - długość dzielnej (n)
; rdx - dzielnik (y)

.sprawdz_dzielnik_zero:
; Zgłasza przerwanie, jeśli dzielnik jest zerem    
    cmp rdx, 0  ; Sprawdza, czy dzielnik jest zerem
    jz .zero    ; Jeśli tak, zgłasza przerwanie

.zachowaj_rejestr:
    push r13

.sprawdz_znak_dzielnika:
; Umieszcza znak dzielnika w r9
    mov r8, rdx                ; Ładuje dzielnik do r8
    shr r8, 63                 ; Zostawia w r8 najstarszy bit dzielnika (bit znaku)
    mov r9, r8                 ; Ładuje bit znaku dzielnika do r9
    cmp r8, 0                  ; Sprawdza czy dzielnik jest dodatni
    jz .sprawdz_znak_dzielnej  ; Jeśli jest dodatni, idzie dalej
    neg rdx                    ; W p.p. zamienia dzielnik na dodatni

.sprawdz_znak_dzielnej:
; Umieszcza znak ilorazu x/y w r9
; Umieszcza znak dzielnej w r8
    lea rax, [rdi + 8 * (rsi - 1)]  ; Ładuje do rax adres najstarszych bitów dzielnej
    mov r8, [rax]                   ; Ładuje najstarsze bity dzielnej do r8
    shr r8, 63                      ; Zostawia w r8 najstarszy bit dzielnej (bit znaku)
    xor r9, r8                      ; Wyznacza znak ilorazu - XOR znaku dzielnika i dzielnej
    cmp r8, 0                       ; Sprawdza czy dzielna jest dodatnia
    jz .relokuj_dzielnik            ; Jeśli jest dodatnia, idzie dalej
                                    ; W p.p. zmienia znak dzielnej na dodatni

.pierwsza_zmiana_znaku:
    mov r13, 0  ; Ustawia informację, że to pierwsza zmiana znaku dzielnej

.zmien_znak_dzielnej:
; Ustawia zmienne pomocnicze do iteracji w pętlach: neguj_dodaj_1, zaneguj_reszte
; Razem te trzy bloki zmieniają znak dzielnej na przeciwny
    lea rcx, [rdi + 8 * (rsi - 1)]  ; Ładuje do rcx adres najstarszych bitów dzielnej
    mov rax, rdi                    ; Ładuje do rax adres najmłodszych bitów dzielnej
    mov r11, rsi                    ; Ładuje do rsi liczbę segmentów dzielnej
    
.neguj_dodaj_1:
; Neguje kolejne segmenty dzielnej i dodaje jeden, aż nie nastąpi przepełnienie
    neg qword [rax]         ; Neguje wskazany segment i dodaje 1
    dec r11                 ; Zmniejsza pozostałą liczbę segmentów
    cmp r11, 0              ; Sprawdza, czy doszedł do końca dzielnej
    jz .po_zmianie_znaku    ; Jeśli tak, skończył zmianę znaku
                            ; W p.p. kontynuuje zmianę znaku
    add rax, 8              ; Ustawia adres na następny segment dzielnej
    cmp qword [rax - 8], 0  ; Sprawdza, czy poprzedni segment się wyzerował
    jz .neguj_dodaj_1       ; Jeśli tak, nastąpiło przeniesienie, więc wykonuje się dla następnego segmentu
    

.zaneguj_reszte:
; Neguje segmenty dzielnej, których nie zanegowała pętla neguj_dodaj_1
    not qword [rax]        ; Neguje wskazany segment
    dec r11
    cmp r11, 0             ; Sprawdza, czy doszedł do końca dzielnej
    jnz .starszy_segment   ; Jeśli nie, przechodzi do następnego segmentu
    jz .po_zmianie_znaku   ; W p.p. skończył zmianę znaku

.starszy_segment:
; Blok pomocniczy dla zaneguj_reszte
; Ustawia adres w rax na starszy segment dzielnej
    add rax, 8            
    jmp .zaneguj_reszte

.po_zmianie_znaku:
; Blok zmiany znaku dzielnej jest potencjalnie wykorzystywany dwa razy
; Ten blok skacze do odpowiedniego miejsca w zależności od tego, czy
; zmienia znak pierwszy, czy drugi razy
; r13 = 0 -> pierwszy raz
; r13 = 1 -> drugi raz 
    cmp r13, 1  ; Sprawdza czy ma przejść do zwrócenia wyniku 
    jz .zwroc   ; Jeśli tak, zwraca wynik
                ; W p.p. idzie dalej

.relokuj_dzielnik:
    mov rcx, rdx  ; Umieszcza dzielnik w rcx

; Aktualna zawartość rejestrów:
; rdi - adres dzielnej
; rsi - długość dzielnej
; rcx - dzielnik
; r8  - znak dzielnej
; r9  - znak ilorazu

.dziel:
; Ustawia zmienne pomocnicze dla pętli dziel_nastepny
    lea r10, [rdi + 8 * (rsi - 1)]  ; Ładuje do r10 adres najstarszych bitów dzielnej
    mov r11, rsi                    ; Ładuje do r11 liczbę segmentów do podzielenia
    xor rdx, rdx                    ; Zeruje rdx

.dziel_nastepny:
; Dzieli wszystkie segmenty dzielnej przez dzielnik
; Wyniki cząstkowe zapisuje w segmentach dzielnej, które były dzielone
; Następne dzielenie jest dzieleniem reszty poprzedniego dzielenia i następnego segmentu (rdx:rax)
    mov rax, [r10]          ; Ładuje segment dzielnej do rax
    div rcx                 ; Dzieli segment dzielnej przez dzielnik
    dec r11                 ; Zmniejsza liczbę segmentów do podzielenia
    mov [r10], rax          ; Zapisuje wynik dzielenia w tym segmencie dzielnej
    cmp r11, 0              ; Sprawdza czy podzielił wszystkie segmenty
    jnz .dziel_nastepny     ; Jeśli nie, dzieli następny segment
    jz .popraw_znak_reszty  ; W p.p. kończy dzielenie

.mlodszy_segment:
; Blok pomocniczy dla dziel_nastepny
; Zmienia adres w r10 na następny młodszy segment
    sub r10, 8           
    jmp .dziel_nastepny  

; W tablicy (oryginalnej dzielnej) znajduje się teraz wynik dzielenia abs(x) / abs(y)
; W rdx znajduje się teraz reszta z dzielenia abs(x) / abs(y)

.popraw_znak_reszty:
    cmp r8, 0               ; Sprawdza czy znak dzielnej był oryginalnie dodatni
    jz .popraw_znak_wyniku  ; Jeśli tak, kończy poprawianie znaku reszty
    neg rdx                 ; W p.p. zmień znak reszty na ujemny

.popraw_znak_wyniku:
    cmp r9, 0   ; Sprawdza, czy znak ilorazu ma być dodatni
    jz .zwroc   ; Jeśli tak, zwraca wynik
    mov r13, 1  ; Ustawia informację, że to druga zmiana znaku dzielnej
    jmp .zmien_znak_dzielnej

.zwroc:
; Zwraca resztę z dzielenia x/y
    mov rax, rdx  ; Ładuje resztę z dzielenia x/y do rax
    pop r13       ; Przywraca wartość r13 sprzed wykonania funkcji
    ret

.zero:
; Zgłasza przerwanie SIGFPE (0)
    xor rdx, rdx  ; Zeruje rdx
    div rdx       ; Zgłasza przerwanie jak 'div'